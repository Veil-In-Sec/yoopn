import '../../domain/entities/vpn_server.dart';

abstract interface class VpnDataSource {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);
}

class SimulatedVpnDataSource implements VpnDataSource {
  const SimulatedVpnDataSource({
    this.connectionDelay = const Duration(milliseconds: 1800),
  });

  final Duration connectionDelay;

  @override
  Future<void> connect(VpnServer server) async {
    await Future<void>.delayed(connectionDelay);
  }

  @override
  Future<void> disconnect() async {}

  @override
  VpnServer? findServer(String name) {
    for (final server in VpnServer.availableServers) {
      if (server.name == name) return server;
    }
    return null;
  }
}
