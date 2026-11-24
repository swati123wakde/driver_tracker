import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/local/location_store.dart';
import '../../data/models/location_record.dart';
import '../../data/remote/mock_location_api.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';

part 'sync_event.dart';
part 'sync_state.dart';

/// Presents sync/connectivity state to the UI and forwards user actions
/// (sync now, simulate offline, mock failure rate). The sync *logic* lives
/// in [SyncService] so it can run and be tested without any widgets.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({
    required SyncService syncService,
    required LocationStore store,
    required ConnectivityService connectivity,
    MockLocationApi? mockApi,
  })  : _sync = syncService,
        _store = store,
        _connectivity = connectivity,
        _mockApi = mockApi,
        super(SyncState(
          simulationAvailable: mockApi != null,
          apiFailureRate: mockApi?.failureRate ?? 0,
        )) {
    on<SyncSubscriptionRequested>(_onSubscribe);
    on<SyncNowPressed>(_onSyncNow, transformer: droppable());
    on<SimulatedOfflineToggled>(_onSimulatedOffline);
    on<ApiFailureRateChanged>(_onFailureRate);
    on<_OnlineChanged>(
      (e, emit) => emit(state.copyWith(isOnline: e.online)),
    );
    on<_PhaseChanged>(
      (e, emit) => emit(state.copyWith(isSyncing: e.phase == SyncPhase.syncing)),
    );
    on<_ReportReceived>(_onReport);
    on<_StoreChanged>(_onRefresh, transformer: restartable());
  }

  final SyncService _sync;
  final LocationStore _store;
  final ConnectivityService _connectivity;
  final MockLocationApi? _mockApi;
  final List<StreamSubscription<dynamic>> _subs = [];

  Future<void> _onSubscribe(
    SyncSubscriptionRequested event,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(
      isOnline: await _connectivity.isOnline,
      simulatedOffline: _connectivity.simulatedOffline,
      isSyncing: _sync.isSyncing,
    ));
    _subs
      ..add(_connectivity.onlineChanges.listen((o) => add(_OnlineChanged(o))))
      ..add(_sync.phaseChanges.listen((p) => add(_PhaseChanged(p))))
      ..add(_sync.reports.listen((r) => add(_ReportReceived(r))))
      ..add(_store.changes.listen((_) => add(const _StoreChanged())));
    add(const _StoreChanged());
  }

  Future<void> _onSyncNow(SyncNowPressed event, Emitter<SyncState> emit) async {
    try {
      await _sync.sync(ignoreBackoff: true);
    } catch (e) {
      emit(state.copyWith(lastError: () => e.toString()));
    }
  }

  void _onSimulatedOffline(
    SimulatedOfflineToggled event,
    Emitter<SyncState> emit,
  ) {
    _connectivity.setSimulatedOffline(event.offline);
    emit(state.copyWith(simulatedOffline: event.offline));
  }

  void _onFailureRate(ApiFailureRateChanged event, Emitter<SyncState> emit) {
    _mockApi?.failureRate = event.rate;
    emit(state.copyWith(apiFailureRate: event.rate));
  }

  void _onReport(_ReportReceived event, Emitter<SyncState> emit) {
    final r = event.report;
    if (r.skippedOffline) return;
    emit(state.copyWith(
      lastSyncAt: () => r.at,
      lastError: () => r.error,
    ));
    add(const _StoreChanged());
  }

  Future<void> _onRefresh(_StoreChanged event, Emitter<SyncState> emit) async {
    final stats = await _store.stats();
    final recent = await _store.recent(limit: 25);
    emit(state.copyWith(
      pending: stats.pending,
      retrying: stats.retrying,
      synced: stats.synced,
      recent: recent,
      serverUnique: _mockApi?.uniqueCount,
      serverDuplicatesIgnored: _mockApi?.duplicatesIgnored,
    ));
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
