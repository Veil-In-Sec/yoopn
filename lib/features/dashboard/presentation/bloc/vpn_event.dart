import 'package:flutter/foundation.dart';

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