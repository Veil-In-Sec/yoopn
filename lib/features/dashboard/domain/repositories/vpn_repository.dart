import '../entities/vpn_server.dart';

abstract interface class VpnRepository {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);

  Future<List<VpnServer>> getServers({bool forceRefresh = false});

  Future<VpnServer?> getBestServer();

  Future<List<VpnServer>> searchServers(String query);

  Stream<String> get connectionDetailStream;

  String get lastConnectionDetail;

  Future<bool> syncTunnelState();
}
