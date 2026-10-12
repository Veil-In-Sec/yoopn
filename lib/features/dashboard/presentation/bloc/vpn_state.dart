import 'package:flutter/foundation.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

enum VpnServersStatus { initial, loading, loaded, failure }

@immutable
class VpnState {
  const VpnState({
    this.status = VpnStatus.disconnected,
    this.server = '',
    this.errorMessage,
    this.servers = VpnServer.availableServers,
    this.serversStatus = VpnServersStatus.initial,
    this.serversError,
    this.connectedSince,
    this.connectionDetail = '',
    this.connectStartedAt,
  });

  final VpnStatus status;

  final String server;
  final String? errorMessage;

  final List<VpnServer> servers;
  final VpnServersStatus serversStatus;
  final String? serversError;

  final DateTime? connectedSince;

  final String connectionDetail;

  final DateTime? connectStartedAt;

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
    String? connectionDetail,
    DateTime? connectStartedAt,
  }) {
    final effectiveStatus = status ?? this.status;
    final isConnecting = effectiveStatus == VpnStatus.connecting;
    final clearedTimer =
        effectiveStatus == VpnStatus.disconnected && connectedSince == null;
    return VpnState(
      status: status ?? this.status,
      server: server ?? this.server,
      errorMessage: errorMessage,
      servers: servers ?? this.servers,
      serversStatus: serversStatus ?? this.serversStatus,
      serversError: serversError,
      connectedSince: clearedTimer ? null : (connectedSince ?? this.connectedSince),
      connectionDetail: isConnecting
          ? (connectionDetail ?? this.connectionDetail)
          : '',
      connectStartedAt: isConnecting
          ? (connectStartedAt ?? this.connectStartedAt)
          : connectStartedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VpnState &&
      other.status == status &&
      other.server == server &&
      other.errorMessage == errorMessage &&
      other.serversStatus == serversStatus &&
      other.serversError == serversError &&
      other.connectedSince == connectedSince &&
      other.connectionDetail == connectionDetail &&
      other.connectStartedAt == connectStartedAt &&
      listEquals(other.servers, servers);

  @override
  int get hashCode => Object.hash(
    status,
    server,
    errorMessage,
    serversStatus,
    serversError,
    connectedSince,
    connectionDetail,
    connectStartedAt,
  );
}
