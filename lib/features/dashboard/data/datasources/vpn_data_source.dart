import '../../domain/entities/vpn_server.dart';

abstract interface class VpnDataSource {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);

  Future<bool> syncTunnelState();

  String get lastStageText;

  Stream<String> get stageTextStream;
}
