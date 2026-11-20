import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/telemetry_point.dart';

abstract class TelemetryQueueStore {
  Future<void> enqueue(TelemetryPoint point);
  Future<List<TelemetryPoint>> getPending({int limit = 50});
  Future<List<TelemetryPoint>> getAllForTrip(String tripId);
  Future<void> markSynced(List<String> clientEventIds);
  Future<int> countPending();
}

/// SQLite-backed offline buffer surviving app restarts and network blackouts.
class SqfliteTelemetryStore implements TelemetryQueueStore {
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'fleet_telemetry_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE telemetry_queue (
            client_event_id TEXT PRIMARY KEY,
            trip_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy_meters REAL NOT NULL,
            speed_kmh REAL NOT NULL,
            heading REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            sync_status TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_telemetry_status_time ON telemetry_queue(sync_status, recorded_at)',
        );
      },
    );
    return _db!;
  }

  @override
  Future<void> enqueue(TelemetryPoint point) async {
    final db = await _database();
    await db.insert(
      'telemetry_queue',
      point.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  @override
  Future<List<TelemetryPoint>> getPending({int limit = 50}) async {
    final db = await _database();
    final rows = await db.query(
      'telemetry_queue',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(TelemetryPoint.fromDbMap).toList();
  }

  @override
  Future<List<TelemetryPoint>> getAllForTrip(String tripId) async {
    final db = await _database();
    final rows = await db.query(
      'telemetry_queue',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(TelemetryPoint.fromDbMap).toList();
  }

  @override
  Future<void> markSynced(List<String> clientEventIds) async {
    if (clientEventIds.isEmpty) return;
    final db = await _database();
    final placeholders = List.filled(clientEventIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE telemetry_queue SET sync_status = ? WHERE client_event_id IN ($placeholders)',
      ['synced', ...clientEventIds],
    );
  }

  @override
  Future<int> countPending() async {
    final db = await _database();
    final res = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM telemetry_queue WHERE sync_status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }
}

/// Deterministic in-memory queue for unit and widget tests.
class InMemoryTelemetryStore implements TelemetryQueueStore {
  final List<TelemetryPoint> _items = [];

  @override
  Future<void> enqueue(TelemetryPoint point) async {
    final exists = _items.any((e) => e.clientEventId == point.clientEventId);
    if (!exists) {
      _items.add(point);
    }
  }

  @override
  Future<List<TelemetryPoint>> getPending({int limit = 50}) async {
    final pending = _items
        .where((e) => e.syncStatus == 'pending')
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return pending.take(limit).toList();
  }

  @override
  Future<List<TelemetryPoint>> getAllForTrip(String tripId) async {
    return _items.where((e) => e.tripId == tripId).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  @override
  Future<void> markSynced(List<String> clientEventIds) async {
    final idSet = clientEventIds.toSet();
    for (var i = 0; i < _items.length; i++) {
      if (idSet.contains(_items[i].clientEventId)) {
        _items[i] = _items[i].copyWith(syncStatus: 'synced');
      }
    }
  }

  @override
  Future<int> countPending() async {
    return _items.where((e) => e.syncStatus == 'pending').length;
  }
}
