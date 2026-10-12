import 'package:flutter/foundation.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

@immutable
sealed class VpnEvent {
  const VpnEvent();
}

final class VpnToggled extends VpnEvent {
  const VpnToggled();
}

final class VpnServerSelected extends VpnEvent {
  const VpnServerSelected(this.server);

  final String server;
}

final class VpnServersRequested extends VpnEvent {
  const VpnServersRequested({this.forceRefresh = false});

  final bool forceRefresh;
}

final class VpnConnectionDetailChanged extends VpnEvent {
  const VpnConnectionDetailChanged(this.detail);

  final String detail;
}

final class VpnTunnelSyncRequested extends VpnEvent {
  const VpnTunnelSyncRequested();
}

final class VpnServersBackgroundRefreshed extends VpnEvent {
  const VpnServersBackgroundRefreshed(this.servers);

  final List<VpnServer> servers;
}

final class VpnServersBackgroundFailed extends VpnEvent {
  const VpnServersBackgroundFailed(this.error);

  final Object error;
}