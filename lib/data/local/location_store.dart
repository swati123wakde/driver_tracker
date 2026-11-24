import '../models/location_record.dart';

enum StoreChange { inserted, updated }

class StoreStats {
  const StoreStats({this.pending = 0, this.retrying = 0, this.synced = 0});

  /// Not yet acknowledged by the server (includes [retrying]).
  final int pending;

  /// Pending records that already failed at least once.
  final int retrying;
  final int synced;
}

/// Local, durable store for location points. Every GPS fix is written here
/// first (offline-first); the sync engine reads pending rows from it.
abstract class LocationStore {
  /// Emits after every write so listeners (sync engine, UI) can react.
  Stream<StoreChange> get changes;

  /// Inserts a record. Returns false if a record with the same id exists.
  Future<bool> insert(LocationRecord record);

  /// Unsynced records whose `nextAttemptAt` is at or before [dueBy],
  /// oldest first.
  Future<List<LocationRecord>> pendingDue(DateTime dueBy, {int limit = 50});

  Future<void> markSynced(List<String> ids, DateTime syncedAt);

  /// Persists attempts / nextAttemptAt / lastError for the given records.
  Future<void> saveRetryState(List<LocationRecord> records);

  /// Earliest `nextAttemptAt` among unsynced records, or null if none.
  Future<DateTime?> earliestPendingAttempt();

  Future<StoreStats> stats();

  /// Most recent records first.
  Future<List<LocationRecord>> recent({int limit = 20});

  Future<void> close();
}
