import 'dart:async';

import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_data_source.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

/// Tunnel status reported by the native VPN layer.
enum VpnTunnelStatus { disconnected, connecting, connected, error }

/// Swappable VPN tunnel.
///
/// - Mobile (Android/iOS): [OpenVpnTunnel] (real OpenVPN via `openvpn_flutter`,
///   VPNGate `vpn`/`vpn` credentials). Registered in DI.
/// - Desktop/web/tests: [SimulatedVpnTunnel] (1800ms fake handshake).
/// Bloc/UI talk only to [VpnTunnel] so the swap is invisible to them.
abstract interface class VpnTunnel {
  Stream<VpnTunnelStatus> get statusStream;

  VpnTunnelStatus get currentStatus;

  /// Human-readable sub-stage of an in-progress connection
  /// (e.g. `Authenticating…`). Empty string when idle.
  /// Backs the "Connecting…" detail line so the UI never looks frozen.
  String get lastStageText;

  /// Emits [lastStageText] whenever the engine reports progress.
  Stream<String> get stageTextStream;

  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  /// Reconciles with the OS tunnel after an app restart.
  ///
  /// The native VpnService outlives the Flutter process: kill the app while
  /// connected and the OS keeps routing traffic (status-bar VPN icon stays
  /// on) while a fresh app instance boots believing it is disconnected.
  /// Returns true when the engine reports a live tunnel, which the caller
  /// should adopt as its state. Never throws — false means "not connected".
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
    final half = Duration(
      milliseconds: connectionDelay.inMilliseconds ~/ 2,
    );
    await Future<void>.delayed(half);
    if (_status == VpnTunnelStatus.connecting) _stage('Securing tunnel…');
    await Future<void>.delayed(half);
    _emit(VpnTunnelStatus.connected);
    _stage('Connected');
    AppLogger.i('TUNNEL', 'connected ${server.id}');
  }

  @override
  Future<void> disconnect() async {
    AppLogger.i('TUNNEL', 'disconnect (was $_status)');
    _stage('');
    _emit(VpnTunnelStatus.disconnected);
  }

  @override
  Future<bool> syncState() async {
    // Fresh instance is always idle — nothing to adopt on desktop/tests.
    return _status == VpnTunnelStatus.connected;
  }

  void _emit(VpnTunnelStatus status) {
    AppLogger.d('TUNNEL', 'status $_status → $status');
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }
}

/// [VpnDataSource] backed by a [VpnTunnel] instead of a bare delay.
///
/// Server lookup stays on the static fallback here; the repository resolves
/// against the merged live + cached list first and only falls through here.
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
