part of 'sync_bloc.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

final class SyncSubscriptionRequested extends SyncEvent {
  const SyncSubscriptionRequested();
}

final class SyncNowPressed extends SyncEvent {
  const SyncNowPressed();
}

final class SimulatedOfflineToggled extends SyncEvent {
  const SimulatedOfflineToggled(this.offline);
  final bool offline;

  @override
  List<Object?> get props => [offline];
}

final class ApiFailureRateChanged extends SyncEvent {
  const ApiFailureRateChanged(this.rate);
  final double rate;

  @override
  List<Object?> get props => [rate];
}

final class _OnlineChanged extends SyncEvent {
  const _OnlineChanged(this.online);
  final bool online;

  @override
  List<Object?> get props => [online];
}

final class _PhaseChanged extends SyncEvent {
  const _PhaseChanged(this.phase);
  final SyncPhase phase;

  @override
  List<Object?> get props => [phase];
}

final class _ReportReceived extends SyncEvent {
  const _ReportReceived(this.report);
  final SyncReport report;

  @override
  List<Object?> get props => [report.at, report.uploaded, report.failed];
}

final class _StoreChanged extends SyncEvent {
  const _StoreChanged();
}
