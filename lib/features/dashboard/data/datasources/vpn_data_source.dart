import 'package:yoopn/core/utils/app_logger.dart';
import '../../domain/entities/vpn_server.dart';

abstract interface class VpnDataSource {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);

  /// Latest engine sub-stage text ('' when idle).
  String get lastStageText;

  /// Live sub-stage updates while connecting.
  Stream<String> get stageTextStream;
}

class SimulatedVpnDataSource implements VpnDataSource {
  const SimulatedVpnDataSource({
    this.connectionDelay = const Duration(milliseconds: 1800),
  });

  final Duration connectionDelay;

  @override
  Future<void> connect(VpnServer server) async {
    AppLogger.d('VPN-DS', 'SimulatedVpnDataSource.connect ${server.name} delay=${connectionDelay.inMilliseconds}ms');
    await Future<void>.delayed(connectionDelay);
    AppLogger.d('VPN-DS', 'SimulatedVpnDataSource.connect done');
  }

  @override
  Future<void> disconnect() async {
    AppLogger.d('VPN-DS', 'SimulatedVpnDataSource.disconnect');
  }

  @override
  String get lastStageText => '';

  @override
  Stream<String> get stageTextStream => const Stream.empty();

  @override
  VpnServer? findServer(String name) {
    for (final server in VpnServer.availableServers) {
      if (server.name == name) return server;
    }
    return null;
  }
}
