import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

/// sqflite offline store for the VPNGate relay list.
///
/// Two tables:
/// - `servers`: one row per relay (hostName PK), full JSON columns.
/// - `meta`: single row (id=1) with the last successful fetch timestamp.
///
/// Tests can inject an already-open [Database] (e.g. in-memory via
/// sqflite_common_ffi) through [testDatabase].
abstract interface class VpnLocalDataSource {
  Future<void> cacheServers(List<Map<String, dynamic>> json);

  Future<List<VpnServer>> loadCachedServers({String? query, int? limit});

  Future<List<Map<String, dynamic>>> loadCachedJson({
    String? query,
    int? limit,
  });

  Future<VpnServer?> loadBestServer();

  Future<DateTime?> lastCachedAt();

  Future<void> clear();
}

class SqfliteVpnLocalDataSource implements VpnLocalDataSource {
  SqfliteVpnLocalDataSource({this.testDatabase, this.dbName = 'yoopn.db'});

  static const int schemaVersion = 1;
  static const String tableServers = 'servers';
  static const String tableMeta = 'meta';

  final Database? testDatabase;
  final String dbName;

  Database? _db;

  Future<Database> _open() async {
    if (testDatabase != null) {
      await _ensureSchema(testDatabase!);
      return testDatabase!;
    }
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, dbName),
      version: schemaVersion,
      onCreate: (db, version) => _createSchema(db),
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE $tableServers (
  hostName TEXT PRIMARY KEY,
  ip TEXT NOT NULL,
  score INTEGER NOT NULL DEFAULT 0,
  ping INTEGER NOT NULL DEFAULT -1,
  speed INTEGER NOT NULL DEFAULT 0,
  countryLong TEXT,
  countryShort TEXT,
  sessions INTEGER NOT NULL DEFAULT 0,
  uptime INTEGER NOT NULL DEFAULT 0,
  totalUsers INTEGER NOT NULL DEFAULT 0,
  totalTraffic INTEGER NOT NULL DEFAULT 0,
  logType TEXT,
  operator TEXT,
  message TEXT,
  openVpnConfig TEXT NOT NULL,
  name TEXT,
  flag TEXT,
  fetched_at TEXT NOT NULL
)''');
    await db.execute('''
CREATE TABLE $tableMeta (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  fetched_at TEXT NOT NULL
)''');
  }

  Future<void> _ensureSchema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = tables.map((r) => r['name'] as String).toSet();
    if (!names.contains(tableServers) || !names.contains(tableMeta)) {
      await _createSchema(db);
    }
  }

  @override
  Future<void> cacheServers(List<Map<String, dynamic>> json) async {
    if (json.isEmpty) return;
    try {
      final db = await _open();
      final now = DateTime.now().toIso8601String();
      final batch = db.batch();
      for (final row in json) {
        final map = Map<String, dynamic>.from(row);
        map['fetched_at'] = now;
        batch.insert(
          tableServers,
          {
            'hostName': '${map['hostName'] ?? ''}',
            'ip': '${map['ip'] ?? ''}',
            'score': _asInt(map['score']),
            'ping': _asInt(map['ping'], fallback: -1),
            'speed': _asInt(map['speed']),
            'countryLong': '${map['countryLong'] ?? ''}',
            'countryShort': '${map['countryShort'] ?? ''}',
            'sessions': _asInt(map['sessions']),
            'uptime': _asInt(map['uptime']),
            'totalUsers': _asInt(map['totalUsers']),
            'totalTraffic': _asInt(map['totalTraffic']),
            'logType': '${map['logType'] ?? ''}',
            'operator': '${map['operator'] ?? ''}',
            'message': '${map['message'] ?? ''}',
            'openVpnConfig': '${map['openVpnConfig'] ?? ''}',
            'name': '${map['name'] ?? ''}',
            'flag': '${map['flag'] ?? ''}',
            'fetched_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      batch.insert(tableMeta, {
        'id': 1,
        'fetched_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    } catch (e) {
      throw VpnException('cache-write', 'Could not save servers offline.', e);
    }
  }

  @override
  Future<List<VpnServer>> loadCachedServers({String? query, int? limit}) async {
    final json = await loadCachedJson(query: query, limit: limit);
    return VpnServerModel.serversFromJson(json);
  }

  @override
  Future<List<Map<String, dynamic>>> loadCachedJson({
    String? query,
    int? limit,
  }) async {
    try {
      final db = await _open();
      final where = StringBuffer();
      final args = <Object?>[];
      if (query != null && query.trim().isNotEmpty) {
        final q = '%${query.trim().toLowerCase()}%';
        where.write(
          'WHERE lower(name) LIKE ? OR lower(hostName) LIKE ? '
          'OR ip LIKE ? OR lower(countryShort) LIKE ?',
        );
        args.addAll([q, q, '%${query.trim()}%', q]);
      }
      final rows = await db.query(
        tableServers,
        where: where.isEmpty ? null : where.toString(),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'score DESC, ping ASC',
        limit: limit,
      );
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw VpnException('cache-read', 'Could not load saved servers.', e);
    }
  }

  @override
  Future<VpnServer?> loadBestServer() async {
    try {
      final db = await _open();
      // Prefer reachable relays (ping >= 0), highest score then lowest ping.
      var rows = await db.query(
        tableServers,
        where: 'ping >= 0',
        orderBy: 'score DESC, ping ASC',
        limit: 1,
      );
      rows = rows.isEmpty
          ? await db.query(
              tableServers,
              orderBy: 'score DESC',
              limit: 1,
            )
          : rows;
      if (rows.isEmpty) return null;
      final servers = VpnServerModel.serversFromJson(
        rows.map((r) => Map<String, dynamic>.from(r)).toList(),
      );
      return servers.isEmpty ? null : servers.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<DateTime?> lastCachedAt() async {
    try {
      final db = await _open();
      final rows = await db.query(
        tableMeta,
        where: 'id = ?',
        whereArgs: const [1],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DateTime.tryParse('${rows.first['fetched_at']}');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    await db.delete(tableServers);
    await db.delete(tableMeta);
  }

  int _asInt(Object? v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? fallback;
    return fallback;
  }
}

/// In-memory stand-in for widget/unit tests running on desktop where the
/// sqflite platform channel is unavailable.
class InMemoryVpnLocalDataSource implements VpnLocalDataSource {
  List<Map<String, dynamic>> _rows = [];
  DateTime? _fetchedAt;

  @override
  Future<void> cacheServers(List<Map<String, dynamic>> json) async {
    _rows = json.map((e) => Map<String, dynamic>.from(e)).toList();
    _fetchedAt = DateTime.now();
  }

  @override
  Future<List<VpnServer>> loadCachedServers({String? query, int? limit}) async {
    var servers = VpnServerModel.serversFromJson(await loadCachedJson());
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      servers = servers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.hostName.toLowerCase().contains(q) ||
                s.ip.contains(q),
          )
          .toList();
    }
    if (limit != null && servers.length > limit) {
      servers = servers.sublist(0, limit);
    }
    return servers;
  }

  @override
  Future<List<Map<String, dynamic>>> loadCachedJson({
    String? query,
    int? limit,
  }) async =>
      _rows.map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Future<VpnServer?> loadBestServer() async {
    final servers = await loadCachedServers();
    if (servers.isEmpty) return null;
    final reachable = servers.where((s) => s.ping >= 0).toList();
    final pool = reachable.isEmpty ? servers : reachable;
    pool.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.ping.compareTo(b.ping);
    });
    return pool.first;
  }

  @override
  Future<DateTime?> lastCachedAt() async => _fetchedAt;

  @override
  Future<void> clear() async {
    _rows = [];
    _fetchedAt = null;
  }
}
