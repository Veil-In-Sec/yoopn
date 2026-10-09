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