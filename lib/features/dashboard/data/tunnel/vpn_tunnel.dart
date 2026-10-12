import 'dart:async';

import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_data_source.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

enum VpnTunnelStatus { disconnected, connecting, connected, error }

abstract interface class VpnTunnel {
  Stream<VpnTunnelStatus> get statusStream;

  VpnTunnelStatus get currentStatus;

  String get lastStageText;

  Stream<String> get stageTextStream;

  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  Future<bool> syncState();
}

class SimulatedVpnTunnel implements VpnTunnel {
  SimulatedVpnTunnel({
    this.connectionDelay = const Duration(milliseconds: 1800),
  });

  final Duration connectionDelay;

  final _controller = StreamController<VpnTunnelStatus>.broadcast();
  final _stageController = StreamController<String>.broadcast();
  VpnTunnelStatus _status = VpnTunnelStatus.disconnected;
  String _stageText = '';

  /// Monotonic token: disconnect() bumps it so a superseded connect() can
  /// never emit `connected` afterwards.
  int _attempt = 0;

  @override
  Stream<VpnTunnelStatus> get statusStream => _controller.stream;

  @override
  VpnTunnelStatus get currentStatus => _status;

  @override
  String get lastStageText => _stageText;

  @override
  Stream<String> get stageTextStream => _stageController.stream;

  void _stage(String text) {
    _stageText = text;
    AppLogger.d('TUNNEL', 'stage: $text');
    if (!_stageController.isClosed) _stageController.add(text);
  }

  @override
  Future<void> connect(VpnServer server) async {
    AppLogger.i('TUNNEL', 'connect → ${server.id} (${server.ip}) cfgLen=${server.openVpnConfig.length}');
    if (server.isVpnGate && server.decodedOpenVpnConfig.isEmpty) {
      AppLogger.w('TUNNEL', 'bad OpenVPN config for ${server.id}');
      throw const VpnException(
        'bad-config',
        'This relay has an unreadable OpenVPN config. Pick another server.',
      );
    }
    _emit(VpnTunnelStatus.connecting);
    _stage('Preparing…');
    AppLogger.d('TUNNEL', 'handshake… delay=${connectionDelay.inMilliseconds}ms');
    final attempt = ++_attempt;
    final half = Duration(
      milliseconds: connectionDelay.inMilliseconds ~/ 2,
    );
    await Future<void>.delayed(half);
    if (attempt != _attempt) return;
    if (_status == VpnTunnelStatus.connecting) _stage('Securing tunnel…');
    await Future<void>.delayed(half);
    if (attempt != _attempt) return;
    _emit(VpnTunnelStatus.connected);
    _stage('Connected');
    AppLogger.i('TUNNEL', 'connected ${server.id}');
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i('TUNNEL', 'disconnect (was $_status)');
    _attempt++;
    _stage('');
    _emit(VpnTunnelStatus.disconnected);
  }

  @override
  Future<bool> syncState() async {
    return _status == VpnTunnelStatus.connected;
  }

  void _emit(VpnTunnelStatus status) {
    AppLogger.d('TUNNEL', 'status $_status → $status');
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }
}

class TunnelVpnDataSource implements VpnDataSource {
  TunnelVpnDataSource({required this.tunnel});

  final VpnTunnel tunnel;

  @override
  Future<void> connect(VpnServer server) => tunnel.connect(server);

  @override
  Future<void> disconnect() => tunnel.disconnect();

  @override
  Future<bool> syncTunnelState() => tunnel.syncState();

  @override
  String get lastStageText => tunnel.lastStageText;

  @override
  Stream<String> get stageTextStream => tunnel.stageTextStream;

  @override
  VpnServer? findServer(String name) {
    for (final server in VpnServer.availableServers) {
      if (server.matchesId(name)) return server;
    }
    return null;
  }
}
