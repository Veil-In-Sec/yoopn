import '../entities/vpn_server.dart';

abstract interface class VpnRepository {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);
}
