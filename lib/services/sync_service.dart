import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import '../data/local/location_store.dart';
import '../data/models/location_record.dart';
import '../data/remote/location_api.dart';
import 'connectivity_service.dart';
import 'retry_policy.dart';

enum SyncPhase { idle, syncing }

class SyncReport {
  const SyncReport({
    required this.at,
    this.uploaded = 0,
    this.failed = 0,
    this.skippedOffline = false,
    this.error,
  });

  final DateTime at;
  final int uploaded;
  final int failed;
  final bool skippedOffline;
  final String? error;

  SyncReport merge(SyncReport next) => SyncReport(
        at: next.at,
        uploaded: uploaded + next.uploaded,
        failed: failed + next.failed,
        skippedOffline: next.skippedOffline,
        error: next.error ?? error,
      );
}

/// Pushes pending location records to the backend.
///
/// Guarantees:
/// * **Single flight:** at most one upload run at a time. Calls made during
///   a run share its future and queue one follow-up run, so a record is
///   never in two concurrent requests.
/// * **At-least-once + idempotent server = exactly-once storage:** records
///   are marked synced only after the server acknowledges them. If the
///   acknowledgement is lost, the record is resent with the same id and the
///   server deduplicates it.
/// * **Backoff:** failed records get `attempts + 1` and a `nextAttemptAt`
///   from [RetryPolicy]; they are skipped until due. Nothing is ever dropped.
///
/// Triggers: connectivity regained, new record inserted (debounced),
/// a retry becoming due, app start, or a manual "Sync now".
class SyncService {
  SyncService({
    required LocationStore store,
    required LocationApi api,
    required ConnectivityService connectivity,
    this.retryPolicy = const RetryPolicy(),
    this.batchSize = 25,
    this.insertDebounce = const Duration(seconds: 1),
    this.autoRetry = true,
    DateTime Function()? clock,
    Random? random,
  })  : _store = store,
        _api = api,
        _connectivity = connectivity,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final LocationStore _store;
  final LocationApi _api;
  final ConnectivityService _connectivity;
  final RetryPolicy retryPolicy;
  final int batchSize;
  final Duration insertDebounce;
  final bool autoRetry;
  final DateTime Function() _clock;
  final Random _random;

  final _phase = StreamController<SyncPhase>.broadcast();
  final _reports = StreamController<SyncReport>.broadcast();

  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<StoreChange>? _storeSub;
  Timer? _retryTimer;
  Timer? _debounceTimer;

  Future<SyncReport>? _inFlight;
  bool _rerunRequested = false;
  bool _ignoreBackoffNext = false;
  bool _disposed = false;

  Stream<SyncPhase> get phaseChanges => _phase.stream;
  Stream<SyncReport> get reports => _reports.stream;
  bool get isSyncing => _inFlight != null;

  /// Wires up automatic triggers and drains anything left from a previous
  /// app session.
  void start() {
    _connectivitySub = _connectivity.onlineChanges.listen((online) {
      if (online) {
        requestSync();
      } else {
        _retryTimer?.cancel();
      }
    });
    _storeSub = _store.changes.listen((change) {
      // Only react to new data; our own "updated" writes must not loop.
      if (change != StoreChange.inserted) return;
      _debounceTimer?.cancel();
      if (insertDebounce == Duration.zero) {
        requestSync();
      } else {
        _debounceTimer = Timer(insertDebounce, requestSync);
      }
    });
    requestSync();
  }

  /// Fire-and-forget variant of [sync] for event handlers and timers.
  void requestSync({bool ignoreBackoff = false}) {
    unawaited(sync(ignoreBackoff: ignoreBackoff).then<void>(
      (_) {},
      onError: (Object e, StackTrace s) =>
          developer.log('Sync failed', error: e, stackTrace: s, name: 'sync'),
    ));
  }

  /// Runs (or joins) a sync. [ignoreBackoff] retries failed records now
  /// instead of waiting for their scheduled time (used by "Sync now").
  Future<SyncReport> sync({bool ignoreBackoff = false}) {
    _ignoreBackoffNext = _ignoreBackoffNext || ignoreBackoff;
    final inFlight = _inFlight;
    if (inFlight != null) {
      _rerunRequested = true;
      return inFlight;
    }
    final run = _runLoop();
    _inFlight = run;
    return run;
  }

  Future<SyncReport> _runLoop() async {
    _emitPhase(SyncPhase.syncing);
    var total = SyncReport(at: _clock());
    try {
      do {
        _rerunRequested = false;
        final ignoreBackoff = _ignoreBackoffNext;
        _ignoreBackoffNext = false;
        final report = await _drainOnce(ignoreBackoff: ignoreBackoff);
        total = total.merge(report);
        if (report.skippedOffline) break;
      } while (_rerunRequested && !_disposed);
    } finally {
      _inFlight = null;
      _emitPhase(SyncPhase.idle);
    }
    if (!_disposed) {
      _reports.add(total);
      await _scheduleRetry();
    }
    return total;
  }

  Future<SyncReport> _drainOnce({required bool ignoreBackoff}) async {
    if (!await _connectivity.isOnline) {
      return SyncReport(at: _clock(), skippedOffline: true);
    }

    var uploaded = 0;
    var failed = 0;
    String? error;

    while (!_disposed) {
      final dueBy = ignoreBackoff ? DateTime(9999) : _clock();
      final batch = await _store.pendingDue(dueBy, limit: batchSize);
      if (batch.isEmpty) break;

      try {
        final acked = (await _api.uploadBatch(batch)).toSet();
        final ackedInBatch =
            batch.where((r) => acked.contains(r.id)).map((r) => r.id).toList();
        await _store.markSynced(ackedInBatch, _clock());
        uploaded += ackedInBatch.length;

        final missing = batch.where((r) => !acked.contains(r.id)).toList();
        if (missing.isNotEmpty) {
          error = 'Server did not acknowledge ${missing.length} record(s)';
          await _markFailed(missing, error);
          failed += missing.length;
          break;
        }
      } catch (e) {
        error = e.toString();
        await _markFailed(batch, error);
        failed += batch.length;
        break; // stop hammering a failing server; backoff takes over
      }
    }

    return SyncReport(
      at: _clock(),
      uploaded: uploaded,
      failed: failed,
      error: error,
    );
  }

  Future<void> _markFailed(List<LocationRecord> records, String error) {
    final now = _clock();
    final updated = records.map((r) {
      final attempts = r.attempts + 1;
      return r.copyWith(
        attempts: attempts,
        nextAttemptAt: now.add(retryPolicy.delayFor(attempts, _random)),
        lastError: error,
      );
    }).toList();
    return _store.saveRetryState(updated);
  }

  /// Arms a timer for the earliest pending retry. Only while online:
  /// going offline cancels it and reconnecting triggers a sync anyway.
  Future<void> _scheduleRetry() async {
    _retryTimer?.cancel();
    if (!autoRetry || _disposed) return;
    if (!await _connectivity.isOnline) return;
    final next = await _store.earliestPendingAttempt();
    if (next == null || _disposed) return;

    var delay = next.difference(_clock());
    if (delay < const Duration(seconds: 1)) delay = const Duration(seconds: 1);
    _retryTimer = Timer(delay, requestSync);
  }

  void _emitPhase(SyncPhase phase) {
    if (!_disposed) _phase.add(phase);
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    await _connectivitySub?.cancel();
    await _storeSub?.cancel();
    await _phase.close();
    await _reports.close();
  }
}
