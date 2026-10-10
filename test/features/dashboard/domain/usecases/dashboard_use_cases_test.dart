import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';
import 'package:yoopn/features/dashboard/domain/repositories/vpn_repository.dart';
import 'package:yoopn/features/dashboard/domain/usecases/dashboard_use_cases.dart';

class _FakeVpnRepository implements VpnRepository {
  VpnServer? connectedServer;
  bool disconnected = false;

  @override
  Future<void> connect(VpnServer server) async {
    connectedServer = server;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  VpnServer? findServer(String name) {
    for (final server in VpnServer.availableServers) {
      if (server.matchesId(name)) return server;
    }
    return null;
  }

  @override
  Future<List<VpnServer>> getServers({bool forceRefresh = false}) async =>
      VpnServer.availableServers;

  @override
  Future<VpnServer?> getBestServer() async =>
      VpnServer.availableServers.first;

  @override
  Future<List<VpnServer>> searchServers(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return VpnServer.availableServers;
    return VpnServer.availableServers
        .where((s) => s.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Stream<String> get connectionDetailStream => const Stream.empty();

  @override
  String get lastConnectionDetail => '';

  @override
  Future<bool> syncTunnelState() async => false;
}

void main() {
  test('connect and disconnect use cases delegate to the repository', () async {
    final repository = _FakeVpnRepository();
    final useCases = DashboardUseCases.fromRepository(repository);
    const server = VpnServer(name: 'United States', flag: '🇺🇸');

    await useCases.connectVpn(server);
    await useCases.disconnectVpn();

    expect(repository.connectedServer, server);
    expect(repository.disconnected, isTrue);
  });

  test('server selection rejects unknown server names', () {
    final useCases = DashboardUseCases.fromRepository(_FakeVpnRepository());

    expect(useCases.selectVpnServer('Unknown'), isNull);
    expect(
      useCases.selectVpnServer('Germany'),
      const VpnServer(name: 'Germany', flag: '🇩🇪'),
    );
  });
}
