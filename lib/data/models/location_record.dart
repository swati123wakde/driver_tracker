import 'package:equatable/equatable.dart';

/// A raw GPS reading coming from a [LocationSource] (real or simulated).
class LocationFix extends Equatable {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy = 0,
    this.speed = 0,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  /// Horizontal accuracy in metres.
  final double accuracy;

  /// Speed in metres per second.
  final double speed;

  @override
  List<Object?> get props => [latitude, longitude, timestamp, accuracy, speed];
}

/// A persisted location point plus its synchronisation bookkeeping.
///
/// [id] is a client-generated UUID. It doubles as the idempotency key sent
/// to the backend, so a record that is uploaded twice (e.g. the response was
/// lost) is still stored only once on the server.
class LocationRecord extends Equatable {
  LocationRecord({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.recordedAt,
    this.syncedAt,
    this.attempts = 0,
    DateTime? nextAttemptAt,
    this.lastError,
  }) : nextAttemptAt = nextAttemptAt ?? recordedAt;

  factory LocationRecord.fromFix({
    required String id,
    required String sessionId,
    required LocationFix fix,
  }) {
    return LocationRecord(
      id: id,
      sessionId: sessionId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracy: fix.accuracy,
      speed: fix.speed,
      recordedAt: fix.timestamp,
    );
  }

  factory LocationRecord.fromDb(Map<String, Object?> row) {
    DateTime? ts(Object? v) =>
        v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);

    return LocationRecord(
      id: row['id']! as String,
      sessionId: row['session_id']! as String,
      latitude: (row['latitude']! as num).toDouble(),
      longitude: (row['longitude']! as num).toDouble(),
      accuracy: (row['accuracy']! as num).toDouble(),
      speed: (row['speed']! as num).toDouble(),
      recordedAt: ts(row['recorded_at'])!,
      syncedAt: ts(row['synced_at']),
      attempts: row['attempts']! as int,
      nextAttemptAt: ts(row['next_attempt_at']),
      lastError: row['last_error'] as String?,
    );
  }

  final String id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final DateTime recordedAt;

  /// Null until the server has acknowledged this record.
  final DateTime? syncedAt;

  /// Number of failed upload attempts so far.
  final int attempts;

  /// Earliest moment the sync engine may (re)try this record.
  final DateTime nextAttemptAt;
  final String? lastError;

  bool get isSynced => syncedAt != null;
  bool get isRetrying => !isSynced && attempts > 0;

  LocationRecord copyWith({
    DateTime? syncedAt,
    int? attempts,
    DateTime? nextAttemptAt,
    String? lastError,
    bool clearError = false,
  }) {
    return LocationRecord(
      id: id,
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      recordedAt: recordedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, Object?> toDb() => {
        'id': id,
        'session_id': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'recorded_at': recordedAt.millisecondsSinceEpoch,
        'synced_at': syncedAt?.millisecondsSinceEpoch,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt.millisecondsSinceEpoch,
        'last_error': lastError,
      };

  /// Wire format for the REST API.
  Map<String, Object?> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'lat': latitude,
        'lng': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        sessionId,
        latitude,
        longitude,
        accuracy,
        speed,
        recordedAt,
        syncedAt,
        attempts,
        nextAttemptAt,
        lastError,
      ];
}
