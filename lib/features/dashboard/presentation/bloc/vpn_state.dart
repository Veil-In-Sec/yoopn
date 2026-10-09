import 'package:flutter/foundation.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/presentation/helper/vpn_status.dart';

@immutable
class VpnState {
  const VpnState({
    this.status = VpnStatus.disconnected,
    this.server = 'United States',
    this.errorMessage,
  });

  static const List<VpnServer> servers = VpnServer.availableServers;

  final VpnStatus status;
  final String server;
  final String? errorMessage;

  VpnState copyWith({VpnStatus? status, String? server, String? errorMessage}) {
    return VpnState(
      status: status ?? this.status,
      server: server ?? this.server,
      errorMessage: errorMessage,
    );
  }

  // Value equality so Bloc skips emitting identical states.
  @override
  bool operator ==(Object other) =>
      other is VpnState &&
      other.status == status &&
      other.server == server &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(status, server, errorMessage);
}
