import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../data/local/location_store.dart';
import '../../data/models/location_record.dart';
import '../../services/location_source.dart';

part 'tracking_event.dart';
part 'tracking_state.dart';

/// Owns the tracking session: starts/stops the [LocationSource] and writes
/// every fix to the local store. It never talks to the network; uploading
/// is the sync engine's job. So tracking behaves the same online or offline.
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc({
    required LocationSource source,
    required LocationStore store,
    Uuid uuid = const Uuid(),
  })  : _source = source,
        _store = store,
        _uuid = uuid,
        super(TrackingState(sourceLabel: source.label)) {
    on<TrackingStartRequested>(_onStart);
    on<TrackingStopRequested>(_onStop);
    on<_FixReceived>(_onFix);
    on<_TrackingFailed>(_onFailed);
  }

  final LocationSource _source;
  final LocationStore _store;
  final Uuid _uuid;
  StreamSubscription<LocationFix>? _subscription;

  Future<void> _onStart(
    TrackingStartRequested event,
    Emitter<TrackingState> emit,
  ) async {
    if (state.status == TrackingStatus.tracking) return;
    await _subscription?.cancel();

    emit(state.copyWith(
      status: TrackingStatus.tracking,
      sessionId: _uuid.v4(),
      pointsThisSession: 0,
      clearError: true,
    ));

    _subscription = _source.watch().listen(
          (fix) => add(_FixReceived(fix)),
          onError: (Object e) => add(_TrackingFailed(e.toString())),
        );
  }

  Future<void> _onFix(_FixReceived event, Emitter<TrackingState> emit) async {
    final sessionId = state.sessionId;
    if (state.status != TrackingStatus.tracking || sessionId == null) return;

    final record = LocationRecord.fromFix(
      id: _uuid.v4(),
      sessionId: sessionId,
      fix: event.fix,
    );
    await _store.insert(record);

    emit(state.copyWith(
      lastFix: event.fix,
      pointsThisSession: state.pointsThisSession + 1,
    ));
  }

  Future<void> _onStop(
    TrackingStopRequested event,
    Emitter<TrackingState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = null;
    emit(state.copyWith(status: TrackingStatus.idle));
  }

  Future<void> _onFailed(
    _TrackingFailed event,
    Emitter<TrackingState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = null;
    emit(state.copyWith(
      status: TrackingStatus.error,
      errorMessage: event.message,
    ));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
