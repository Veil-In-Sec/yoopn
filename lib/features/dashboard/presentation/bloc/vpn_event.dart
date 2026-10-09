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