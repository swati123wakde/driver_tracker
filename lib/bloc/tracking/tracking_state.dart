part of 'tracking_bloc.dart';

enum TrackingStatus { idle, tracking, error }

final class TrackingState extends Equatable {
  const TrackingState({
    this.status = TrackingStatus.idle,
    this.sourceLabel = '',
    this.sessionId,
    this.lastFix,
    this.pointsThisSession = 0,
    this.errorMessage,
  });

  final TrackingStatus status;
  final String sourceLabel;
  final String? sessionId;
  final LocationFix? lastFix;
  final int pointsThisSession;
  final String? errorMessage;

  bool get isTracking => status == TrackingStatus.tracking;

  TrackingState copyWith({
    TrackingStatus? status,
    String? sessionId,
    LocationFix? lastFix,
    int? pointsThisSession,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TrackingState(
      status: status ?? this.status,
      sourceLabel: sourceLabel,
      sessionId: sessionId ?? this.sessionId,
      lastFix: lastFix ?? this.lastFix,
      pointsThisSession: pointsThisSession ?? this.pointsThisSession,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, sourceLabel, sessionId, lastFix, pointsThisSession, errorMessage];
}
