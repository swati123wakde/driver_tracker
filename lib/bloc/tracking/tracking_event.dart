part of 'tracking_bloc.dart';

sealed class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

final class TrackingStartRequested extends TrackingEvent {
  const TrackingStartRequested();
}

final class TrackingStopRequested extends TrackingEvent {
  const TrackingStopRequested();
}

final class _FixReceived extends TrackingEvent {
  const _FixReceived(this.fix);
  final LocationFix fix;

  @override
  List<Object?> get props => [fix];
}

final class _TrackingFailed extends TrackingEvent {
  const _TrackingFailed(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
