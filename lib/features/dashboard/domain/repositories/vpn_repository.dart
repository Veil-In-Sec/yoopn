import '../entities/vpn_server.dart';

abstract interface class VpnRepository {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);

  /// Live VPNGate relay list. Falls back to sqflite cache, then memory,
  /// then [VpnServer.availableServers] when the network request fails.
  Future<List<VpnServer>> getServers({bool forceRefresh = false});

  /// Highest-score / lowest-ping relay, preferably from the offline cache.
  Future<VpnServer?> getBestServer();

  /// Offline-capable search over cached relays.
  Future<List<VpnServer>> searchServers(String query);
}
