part of 'sync_bloc.dart';

final class SyncState extends Equatable {
  const SyncState({
    this.isOnline = false,
    this.simulatedOffline = false,
    this.isSyncing = false,
    this.pending = 0,
    this.retrying = 0,
    this.synced = 0,
    this.recent = const [],
    this.lastSyncAt,
    this.lastError,
    this.simulationAvailable = false,
    this.apiFailureRate = 0,
    this.serverUnique = 0,
    this.serverDuplicatesIgnored = 0,
  });

  final bool isOnline;
  final bool simulatedOffline;
  final bool isSyncing;
  final int pending;
  final int retrying;
  final int synced;
  final List<LocationRecord> recent;
  final DateTime? lastSyncAt;
  final String? lastError;

  /// True when the in-app mock backend is used (enables demo controls).
  final bool simulationAvailable;
  final double apiFailureRate;
  final int serverUnique;
  final int serverDuplicatesIgnored;

  /// Nullable fields take a getter so callers can explicitly set null.
  SyncState copyWith({
    bool? isOnline,
    bool? simulatedOffline,
    bool? isSyncing,
    int? pending,
    int? retrying,
    int? synced,
    List<LocationRecord>? recent,
    DateTime? Function()? lastSyncAt,
    String? Function()? lastError,
    double? apiFailureRate,
    int? serverUnique,
    int? serverDuplicatesIgnored,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      simulatedOffline: simulatedOffline ?? this.simulatedOffline,
      isSyncing: isSyncing ?? this.isSyncing,
      pending: pending ?? this.pending,
      retrying: retrying ?? this.retrying,
      synced: synced ?? this.synced,
      recent: recent ?? this.recent,
      lastSyncAt: lastSyncAt != null ? lastSyncAt() : this.lastSyncAt,
      lastError: lastError != null ? lastError() : this.lastError,
      simulationAvailable: simulationAvailable,
      apiFailureRate: apiFailureRate ?? this.apiFailureRate,
      serverUnique: serverUnique ?? this.serverUnique,
      serverDuplicatesIgnored:
          serverDuplicatesIgnored ?? this.serverDuplicatesIgnored,
    );
  }

  @override
  List<Object?> get props => [
        isOnline,
        simulatedOffline,
        isSyncing,
        pending,
        retrying,
        synced,
        recent,
        lastSyncAt,
        lastError,
        simulationAvailable,
        apiFailureRate,
        serverUnique,
        serverDuplicatesIgnored,
      ];
}
