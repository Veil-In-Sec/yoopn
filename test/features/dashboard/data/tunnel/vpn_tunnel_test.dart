import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/data/tunnel/vpn_tunnel.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

const String _validConfigB64 =
    'Y2xpZW50CmRldiB0dW4KcHJvdG8gdWRwCnJlbW90ZSAxLjIuMy40IDExOTQ=';

VpnServer _relay({String config = _validConfigB64}) => VpnServer(
      name: 'Japan',
      flag: '🇯🇵',
      hostName: 'public-vpn-1',
      ip: '1.2.3.4',
      openVpnConfig: config,
    );

void main() {
  group('SimulatedVpnTunnel', () {
    late SimulatedVpnTunnel tunnel;
    late List<VpnTunnelStatus> statuses;

    setUp(() {
      tunnel = SimulatedVpnTunnel(
        connectionDelay: const Duration(milliseconds: 40),
      );
      statuses = [];
      tunnel.statusStream.listen(statuses.add);
    });

    test('connect reports connecting then connected', () async {
      await tunnel.connect(_relay());
      await Future<void>.delayed(Duration.zero);

      expect(statuses, [
        VpnTunnelStatus.connecting,
        VpnTunnelStatus.connected,
      ]);
      expect(tunnel.currentStatus, VpnTunnelStatus.connected);
    });

    test('emits human stage text while connecting and clears on disconnect',
        () async {
      final stages = <String>[];
      tunnel.stageTextStream.listen(stages.add);

      await tunnel.connect(_relay());
      expect(stages, contains('Preparing…'));
      expect(stages, contains('Securing tunnel…'));
      expect(tunnel.lastStageText, 'Connected');

      await tunnel.disconnect();
      expect(tunnel.lastStageText, isEmpty);
      expect(tunnel.currentStatus, VpnTunnelStatus.disconnected);
    });

    test('rejects a relay with an unreadable config', () async {
      await expectLater(
        tunnel.connect(_relay(config: '!!!not-base64!!!')),
        throwsA(
          isA<VpnException>().having((e) => e.code, 'code', 'bad-config'),
        ),
      );
      expect(tunnel.currentStatus, VpnTunnelStatus.disconnected);
    });
  });

  group('TunnelVpnDataSource', () {
    late SimulatedVpnTunnel tunnel;
    late TunnelVpnDataSource dataSource;

    setUp(() {
      tunnel = SimulatedVpnTunnel(
        connectionDelay: const Duration(milliseconds: 20),
      );
      dataSource = TunnelVpnDataSource(tunnel: tunnel);
    });

    test('forwards stage text from the tunnel', () async {
      expect(dataSource.lastStageText, isEmpty);
      await dataSource.connect(_relay());
      expect(dataSource.lastStageText, 'Connected');
    });

    test('resolves fallback servers but rejects unknown names', () {
      expect(dataSource.findServer('Germany'), isNotNull);
      expect(dataSource.findServer('does-not-exist'), isNull);
    });
  });
}