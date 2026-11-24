import 'dart:async';

import '../models/location_record.dart';
import 'location_store.dart';

/// Non-persistent [LocationStore], used in tests and as a reference
/// implementation of the store contract.
class InMemoryLocationStore implements LocationStore {
  final Map<String, LocationRecord> _records = {};
  final _changes = StreamController<StoreChange>.broadcast();

  @override
  Stream<StoreChange> get changes => _changes.stream;

  @override
  Future<bool> insert(LocationRecord record) async {
    if (_records.containsKey(record.id)) return false;
    _records[record.id] = record;
    _changes.add(StoreChange.inserted);
    return true;
  }

  @override
  Future<List<LocationRecord>> pendingDue(DateTime dueBy,
      {int limit = 50}) async {
    final due = _records.values
        .where((r) => !r.isSynced && !r.nextAttemptAt.isAfter(dueBy))
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return due.take(limit).toList();
  }

  @override
  Future<void> markSynced(List<String> ids, DateTime syncedAt) async {
    for (final id in ids) {
      final r = _records[id];
      if (r != null) {
        _records[id] = r.copyWith(syncedAt: syncedAt, clearError: true);
      }
    }
    _changes.add(StoreChange.updated);
  }

  @override
  Future<void> saveRetryState(List<LocationRecord> records) async {
    for (final r in records) {
      final existing = _records[r.id];
      if (existing == null) continue;
      _records[r.id] = existing.copyWith(
        attempts: r.attempts,
        nextAttemptAt: r.nextAttemptAt,
        lastError: r.lastError,
      );
    }
    _changes.add(StoreChange.updated);
  }

  @override
  Future<DateTime?> earliestPendingAttempt() async {
    DateTime? earliest;
    for (final r in _records.values) {
      if (r.isSynced) continue;
      if (earliest == null || r.nextAttemptAt.isBefore(earliest)) {
        earliest = r.nextAttemptAt;
      }
    }
    return earliest;
  }

  @override
  Future<StoreStats> stats() async {
    var pending = 0, retrying = 0, synced = 0;
    for (final r in _records.values) {
      if (r.isSynced) {
        synced++;
      } else {
        pending++;
        if (r.attempts > 0) retrying++;
      }
    }
    return StoreStats(pending: pending, retrying: retrying, synced: synced);
  }

  @override
  Future<List<LocationRecord>> recent({int limit = 20}) async {
    final all = _records.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return all.take(limit).toList();
  }

  /// Test helper: look a record up by id.
  LocationRecord? byId(String id) => _records[id];

  @override
  Future<void> close() => _changes.close();
}
