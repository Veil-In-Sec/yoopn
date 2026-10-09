import 'dart:async';

import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_data_source.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

/// Tunnel status reported by the native VPN layer.
enum VpnTunnelStatus { disconnected, connecting, connected, error }

/// Swappable VPN tunnel.
///
/// [SimulatedVpnTunnel] runs everywhere (desktop/test) with the previous
/// 1800ms fake handshake. The native OpenVPN implementation drops in here:
/// implement [VpnTunnel] with the flutter OpenVPN plugin and register it in
/// `dependency_injection.dart` for Android/iOS — no bloc/UI changes needed.
abstract interface class VpnTunnel {
  Stream<VpnTunnelStatus> get statusStream;

  VpnTunnelStatus get currentStatus;

  Future<void> connect(VpnServer server);

  Future<void> disconnect();
}

class SimulatedVpnTunnel implements VpnTunnel {
  SimulatedVpnTunnel({
    this.connectionDelay = const Duration(milliseconds: 1800),
  });

  final Duration connectionDelay;

  final _controller = StreamController<VpnTunnelStatus>.broadcast();
  VpnTunnelStatus _status = VpnTunnelStatus.disconnected;

  @override
  Stream<VpnTunnelStatus> get statusStream => _controller.stream;

  @override
  VpnTunnelStatus get currentStatus => _status;

  @override
  Future<void> connect(VpnServer server) async {
    if (server.isVpnGate && server.decodedOpenVpnConfig.isEmpty) {
      throw const VpnException(
        'bad-config',
        'This relay has an unreadable OpenVPN config. Pick another server.',
      );
    }
    _emit(VpnTunnelStatus.connecting);
    await Future<void>.delayed(connectionDelay);
    _emit(VpnTunnelStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _emit(VpnTunnelStatus.disconnected);
  }

  void _emit(VpnTunnelStatus status) {
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
  VpnServer? findServer(String name) {
    for (final server in VpnServer.availableServers) {
      if (server.matchesId(name)) return server;
    }
    return null;
  }
}
