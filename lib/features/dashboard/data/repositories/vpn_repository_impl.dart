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
    final availableServer = findServer(server.id);
    if (availableServer == null) {
      throw ArgumentError.value(server.id, 'server', 'Unknown VPN server');
    }
    return connectionDataSource.connect(availableServer);
  }

  @override
  Future<void> disconnect() => connectionDataSource.disconnect();

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
    // Fast path: warm memory on plain (non-forced) loads.
    if (!forceRefresh && _servers != VpnServer.availableServers) {
      return _servers;
    }
    // Offline-first boot: serve sqflite rows when present so the UI never
    // waits on the network. A forced refresh skips straight to the network.
    if (!forceRefresh) {
      try {
        final cached = await localDataSource.loadCachedServers();
        if (cached.isNotEmpty) {
          _servers = cached;
          return cached;
        }
      } catch (_) {
        // Fall through to network.
      }
    }
    try {
      final servers = await gateDataSource.fetchServers(
        forceRefresh: forceRefresh,
      );
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
    } catch (_) {
      // Network failed: sqflite -> memory -> static fallback.
      try {
        final cached = await localDataSource.loadCachedServers();
        if (cached.isNotEmpty) {
          _servers = cached;
          return cached;
        }
      } catch (_) {}
      if (_servers.isEmpty) _servers = VpnServer.availableServers;
      return _servers;
    }
  }

  @override
  Future<VpnServer?> getBestServer() async {
    try {
      final best = await localDataSource.loadBestServer();
      if (best != null) return best;
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
    try {
      return await localDataSource.loadCachedServers(query: query);
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
}
