import 'package:flutter/foundation.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

enum VpnServersStatus { initial, loading, loaded, failure }

@immutable
class VpnState {
  const VpnState({
    this.status = VpnStatus.disconnected,
    this.server = 'United States',
    this.errorMessage,
    this.servers = VpnServer.availableServers,
    this.serversStatus = VpnServersStatus.initial,
    this.serversError,
    this.connectedSince,
  });

  final VpnStatus status;

  /// Selected server id (VPNGate hostName, or legacy country name).
  final String server;
  final String? errorMessage;

  /// Live VPNGate list (falls back to [VpnServer.availableServers]).
  final List<VpnServer> servers;
  final VpnServersStatus serversStatus;
  final String? serversError;

  /// When the current connection started (null while disconnected).
  /// Drives the connection-duration readout; cleared on disconnect.
  final DateTime? connectedSince;

  bool get isLoadingServers => serversStatus == VpnServersStatus.loading;

  VpnServer? get selectedServer {
    for (final s in servers) {
      if (s.matchesId(server)) return s;
    }
    return null;
  }

  VpnState copyWith({
    VpnStatus? status,
    String? server,
    String? errorMessage,
    List<VpnServer>? servers,
    VpnServersStatus? serversStatus,
    String? serversError,
    DateTime? connectedSince,
  }) {
    // Disconnect clears the timer; an explicit connectedSince sets it.
    final clearedTimer =
        status == VpnStatus.disconnected && connectedSince == null;
    return VpnState(
      status: status ?? this.status,
      server: server ?? this.server,
      errorMessage: errorMessage,
      servers: servers ?? this.servers,
      serversStatus: serversStatus ?? this.serversStatus,
      serversError: serversError,
      connectedSince: clearedTimer ? null : (connectedSince ?? this.connectedSince),
    );
  }

  // Value equality so Bloc skips emitting identical states.
  @override
  bool operator ==(Object other) =>
      other is VpnState &&
      other.status == status &&
      other.server == server &&
      other.errorMessage == errorMessage &&
      other.serversStatus == serversStatus &&
      other.serversError == serversError &&
      other.connectedSince == connectedSince &&
      listEquals(other.servers, servers);

  @override
  int get hashCode => Object.hash(
    status,
    server,
    errorMessage,
    serversStatus,
    serversError,
    connectedSince,
  );
}
