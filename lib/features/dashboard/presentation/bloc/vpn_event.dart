import 'package:flutter/foundation.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

@immutable
sealed class VpnEvent {
  const VpnEvent();
}

/// Connect when disconnected, disconnect when connected.
final class VpnToggled extends VpnEvent {
  const VpnToggled();
}

final class VpnServerSelected extends VpnEvent {
  const VpnServerSelected(this.server);

  final String server;
}

/// Fetch the live VPNGate relay list.
final class VpnServersRequested extends VpnEvent {
  const VpnServersRequested({this.forceRefresh = false});

  final bool forceRefresh;
}

/// Internal: engine sub-stage text while connecting (e.g. `Assigning IP…`).
/// Forwarded from [VpnTunnel.stageTextStream] so the UI detail line stays live.
final class VpnConnectionDetailChanged extends VpnEvent {
  const VpnConnectionDetailChanged(this.detail);

  final String detail;
}

/// Reconcile with the OS tunnel on entry (e.g. after a process restart).
/// Adopts a still-live tunnel as connected; silent when idle.
final class VpnTunnelSyncRequested extends VpnEvent {
  const VpnTunnelSyncRequested();
}

/// Internal: a refresh that exceeded the foreground budget finished.
/// Carries the fresh list so the UI updates without another fetch.
final class VpnServersBackgroundRefreshed extends VpnEvent {
  const VpnServersBackgroundRefreshed(this.servers);

  final List<VpnServer> servers;
}

/// Internal: a background refresh failed. Only downgrades the UI when
/// there is still nothing usable to show.
final class VpnServersBackgroundFailed extends VpnEvent {
  const VpnServersBackgroundFailed(this.error);

  final Object error;
}