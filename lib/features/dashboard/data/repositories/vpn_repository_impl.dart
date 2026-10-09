import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/vpn_repository.dart';
import '../datasources/vpn_data_source.dart';
import '../datasources/vpn_gate_remote_data_source.dart';
import '../datasources/vpn_local_data_source.dart';

class VpnRepositoryImpl implements VpnRepository {
  VpnRepositoryImpl({
    required this.connectionDataSource,
    required this.gateDataSource,
    required this.localDataSource,
  });

  final VpnDataSource connectionDataSource;
  final VpnGateRemoteDataSource gateDataSource;
  final VpnLocalDataSource localDataSource;

  /// Last known good list. Starts as the static fallback.
  List<VpnServer> _servers = VpnServer.availableServers;

  List<VpnServer> get cachedServers => List.unmodifiable(_servers);

  @override
  Future<void> connect(VpnServer server) {
    AppLogger.i('VPN', 'repo.connect ${server.id}');
    final availableServer = findServer(server.id);
    if (availableServer == null) {
      throw ArgumentError.value(server.id, 'server', 'Unknown VPN server');
    }
    return connectionDataSource.connect(availableServer);
  }

  @override
  Future<void> disconnect() {
    AppLogger.i('VPN', 'repo.disconnect');
    return connectionDataSource.disconnect();
  }

  @override
  VpnServer? findServer(String name) {
    for (final server in _servers) {
      if (server.matchesId(name)) return server;
    }
    for (final server in VpnServer.availableServers) {
      if (server.matchesId(name)) return server;
    }
    return connectionDataSource.findServer(name);
  }

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async {
    AppLogger.d('VPN', 'repo.getServers forceRefresh=$forceRefresh mem=${_servers.length}');
    // Fast path: warm memory on plain (non-forced) loads.
    if (!forceRefresh && _servers != VpnServer.availableServers) {
      AppLogger.d('VPN', 'repo.getServers → memory (${_servers.length})');
      return _servers;
    }
    // Offline-first boot: serve sqflite rows when present so the UI never
    // waits on the network. A forced refresh skips straight to the network.
    if (!forceRefresh) {
      try {
        final cached = await localDataSource.loadCachedServers();
        AppLogger.d('VPN', 'repo offline-first cache → ${cached.length}');
        if (cached.isNotEmpty) {
          _servers = cached;
          AppLogger.i('VPN', 'repo.getServers → offline cache (${cached.length})');
          return cached;
        }
      } catch (e) {
        AppLogger.w('VPN', 'offline cache miss, trying network', e);
        // Fall through to network.
      }
    }
    try {
      AppLogger.i('VPN', 'repo fetching network (force=$forceRefresh)…');
      final servers = await gateDataSource.fetchServers(
        forceRefresh: forceRefresh,
      );
      AppLogger.i('VPN', 'repo network → ${servers.length} servers');
      _servers = servers;
      // Persist JSON for offline boot (fire-and-forget-safe: awaited but
      // non-fatal — a full disk must not break the live list).
      try {
        final json = await gateDataSource.fetchJson();
        await localDataSource.cacheServers(json);
      } catch (_) {
        try {
          await localDataSource.cacheServers(
            servers.map((s) => s.toJson()).toList(),
          );
        } catch (_) {}
      }
      return servers;
    } catch (e, st) {
      AppLogger.e('VPN', 'repo network failed — fallback chain', e, st);
      // Network failed: sqflite -> memory -> static fallback.
      try {
        final cached = await localDataSource.loadCachedServers();
        if (cached.isNotEmpty) {
          _servers = cached;
          AppLogger.w('VPN', 'repo fallback → cache (${cached.length})');
          return cached;
        }
      } catch (_) {}
      if (_servers.isEmpty) _servers = VpnServer.availableServers;
      AppLogger.w('VPN', 'repo fallback → memory/static (${_servers.length})');
      return _servers;
    }
  }

  @override
  Future<VpnServer?> getBestServer() async {
    AppLogger.d('VPN', 'repo.getBestServer');
    try {
      final best = await localDataSource.loadBestServer();
      if (best != null) {
        AppLogger.d('VPN', 'repo best → cache ${best.id}');
        return best;
      }
    } catch (_) {}
    if (_servers.isNotEmpty) {
      final pool = _servers.where((s) => s.ping >= 0).toList();
      final candidates = pool.isEmpty ? _servers : pool;
      candidates.sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) return score;
        return a.ping.compareTo(b.ping);
      });
      return candidates.first;
    }
    return null;
  }

  @override
  Future<List<VpnServer>> searchServers(String query) async {
    AppLogger.d('VPN', 'repo.search "$query"');
    try {
      final r = await localDataSource.loadCachedServers(query: query);
      AppLogger.d('VPN', 'repo.search → ${r.length}');
      return r;
    } catch (_) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return _servers;
      return _servers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.hostName.toLowerCase().contains(q) ||
                s.ip.contains(q),
          )
          .toList();
    }
  }

  @override
  Stream<String> get connectionDetailStream {
    try {
      return connectionDataSource.stageTextStream;
    } catch (e) {
      AppLogger.w('VPN', 'detail stream unavailable: $e');
      return const Stream.empty();
    }
  }
}
