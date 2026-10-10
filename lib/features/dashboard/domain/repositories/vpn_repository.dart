import '../entities/vpn_server.dart';

abstract interface class VpnRepository {
  Future<void> connect(VpnServer server);

  Future<void> disconnect();

  VpnServer? findServer(String name);

  /// Live VPNGate relay list. Falls back to sqflite cache, then memory,
  /// then [VpnServer.availableServers] when the network request fails.
  Future<List<VpnServer>> getServers({bool forceRefresh = false});

  /// Highest-score / lowest-ping relay, preferably from the offline cache.
  Future<VpnServer?> getBestServer();

  /// Offline-capable search over cached relays.
  Future<List<VpnServer>> searchServers(String query);

  /// Live engine sub-stage texts while connecting ('' when idle).
  /// The bloc forwards these to the UI detail line.
  Stream<String> get connectionDetailStream;

  /// Synchronous read of the latest engine sub-stage ('' when idle).
  /// Needed where the stream can't be trusted: failure completers resolve
  /// in a microtask while detail events still sit in the event queue, so
  /// `state.connectionDetail` can lag one stage behind at telemetry time.
  String get lastConnectionDetail;

  /// Adopt a live OS tunnel after an app restart. True when the engine
  /// reports a connected tunnel. Never throws (false when idle).
  Future<bool> syncTunnelState();
}
