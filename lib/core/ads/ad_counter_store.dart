import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

abstract interface class AdCounterStore {
  Future<int> getServerChangeCount();
  Future<void> incrementServerChangeCount();
}

class SqfliteAdCounterStore implements AdCounterStore {
  static const _dbName = 'yoopn_ads.db';
  static const _key = 'server_change_count';

  Database? _db;

  Future<Database>? _opening;

  Future<Database> _open() {
    if (_db != null) return Future.value(_db!);
    final opening = _opening;
    if (opening != null) return opening;
    final future = _doOpen();
    _opening = future;
    future.then((_) {}, onError: (_) {
      if (identical(_opening, future)) _opening = null;
    });
    return future;
  }

  Future<Database> _doOpen() async {
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE kv(key TEXT PRIMARY KEY, value INTEGER NOT NULL DEFAULT 0)',
        );
      },
    );
    return _db!;
  }

  @override
  Future<int> getServerChangeCount() async {
    try {
      final db = await _open();
      final rows = await db.query(
        'kv',
        where: 'key = ?',
        whereArgs: const [_key],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return (rows.first['value'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> incrementServerChangeCount() async {
    // Single-statement upsert: atomic, no lost update under concurrency.
    try {
      final db = await _open();
      await db.rawInsert(
        'INSERT INTO kv(key, value) VALUES(?, 1) '
        'ON CONFLICT(key) DO UPDATE SET value = kv.value + 1',
        [_key],
      );
    } catch (_) {}
  }
}

class MemoryAdCounterStore implements AdCounterStore {
  int _count = 0;

  @override
  Future<int> getServerChangeCount() async => _count;

  @override
  Future<void> incrementServerChangeCount() async => _count++;
}
