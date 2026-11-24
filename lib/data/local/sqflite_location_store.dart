import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/location_record.dart';
import 'location_store.dart';

/// SQLite-backed [LocationStore]. Survives app restarts, so points recorded
/// offline are still uploaded after the app is killed and reopened.
class SqfliteLocationStore implements LocationStore {
  SqfliteLocationStore._(this._db);

  static const _table = 'locations';

  final Database _db;
  final _changes = StreamController<StoreChange>.broadcast();

  static Future<SqfliteLocationStore> open({String name = 'driver_tracker.db'}) async {
    final path = p.join(await getDatabasesPath(), name);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL NOT NULL,
            speed REAL NOT NULL,
            recorded_at INTEGER NOT NULL,
            synced_at INTEGER,
            attempts INTEGER NOT NULL DEFAULT 0,
            next_attempt_at INTEGER NOT NULL,
            last_error TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_pending ON $_table (synced_at, next_attempt_at)',
        );
      },
    );
    return SqfliteLocationStore._(db);
  }

  @override
  Stream<StoreChange> get changes => _changes.stream;

  @override
  Future<bool> insert(LocationRecord record) async {
    // PRIMARY KEY + IGNORE: the same point can never be stored twice locally.
    final rowId = await _db.insert(
      _table,
      record.toDb(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final inserted = rowId > 0; // 0 or -1 when ignored, depending on platform
    if (inserted) _changes.add(StoreChange.inserted);
    return inserted;
  }

  @override
  Future<List<LocationRecord>> pendingDue(DateTime dueBy,
      {int limit = 50}) async {
    final rows = await _db.query(
      _table,
      where: 'synced_at IS NULL AND next_attempt_at <= ?',
      whereArgs: [dueBy.millisecondsSinceEpoch],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(LocationRecord.fromDb).toList();
  }

  @override
  Future<void> markSynced(List<String> ids, DateTime syncedAt) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE $_table SET synced_at = ?, last_error = NULL '
      'WHERE id IN ($placeholders)',
      [syncedAt.millisecondsSinceEpoch, ...ids],
    );
    _changes.add(StoreChange.updated);
  }

  @override
  Future<void> saveRetryState(List<LocationRecord> records) async {
    if (records.isEmpty) return;
    final batch = _db.batch();
    for (final r in records) {
      batch.update(
        _table,
        {
          'attempts': r.attempts,
          'next_attempt_at': r.nextAttemptAt.millisecondsSinceEpoch,
          'last_error': r.lastError,
        },
        where: 'id = ?',
        whereArgs: [r.id],
      );
    }
    await batch.commit(noResult: true);
    _changes.add(StoreChange.updated);
  }

  @override
  Future<DateTime?> earliestPendingAttempt() async {
    final value = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT MIN(next_attempt_at) FROM $_table WHERE synced_at IS NULL',
    ));
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  @override
  Future<StoreStats> stats() async {
    final rows = await _db.rawQuery('''
      SELECT
        SUM(CASE WHEN synced_at IS NULL THEN 1 ELSE 0 END) AS pending,
        SUM(CASE WHEN synced_at IS NULL AND attempts > 0 THEN 1 ELSE 0 END) AS retrying,
        SUM(CASE WHEN synced_at IS NOT NULL THEN 1 ELSE 0 END) AS synced
      FROM $_table
    ''');
    final row = rows.first;
    int read(String key) => (row[key] as int?) ?? 0;
    return StoreStats(
      pending: read('pending'),
      retrying: read('retrying'),
      synced: read('synced'),
    );
  }

  @override
  Future<List<LocationRecord>> recent({int limit = 20}) async {
    final rows =
        await _db.query(_table, orderBy: 'recorded_at DESC', limit: limit);
    return rows.map(LocationRecord.fromDb).toList();
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }
}
