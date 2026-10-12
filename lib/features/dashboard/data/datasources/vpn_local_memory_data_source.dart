import 'package:yoopn/features/dashboard/data/datasources/vpn_local_data_source.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/domain/utils/server_ranking.dart';

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
      servers = servers.where((s) => serverMatchesQuery(s, query)).toList();
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
    pool.sort(compareServersByQuality);
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
