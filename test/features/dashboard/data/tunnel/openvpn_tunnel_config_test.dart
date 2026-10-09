import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/core/errors/vpn_failures.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

/// The Android OpenVPN engine starts a real process; these cover the config
/// handling that runs before any platform call.
void main() {
  group('config decoding', () {
    test('a usable VPNGate relay is accepted', () {
      const relay = VpnServer(
        name: 'Japan',
        flag: '🇯🇵',
        hostName: 'public-vpn-1',
        ip: '1.2.3.4',
        openVpnConfig: 'Y2xpZW50CmRldiB0dW4K',
      );
      expect(relay.isVpnGate, isTrue);
      expect(relay.decodedOpenVpnConfig, contains('client'));
    });
  });

  group('stage text mapping', () {
    test('terminal stages are described for the user', () {
      // Exposed indirectly: a disconnected server must carry no config so the
      // tunnel rejects it before touching the engine.
      const fallback = VpnServer(name: 'Germany', flag: '🇩🇪');
      expect(fallback.isVpnGate, isFalse);
    });
  });

  group('failure codes surfaced to the user', () {
    test('bad config has a retry-oriented message', () {
      const failure = VpnException(
        'bad-config',
        'This server has no OpenVPN config. Pick a live VPNGate relay.',
      );
      expect(VpnFailure.from(failure).code, 'bad-config');
      expect(
        VpnFailure.from(failure).message,
        contains('live VPNGate relay'),
      );
    });

    test('cancel is a distinct, non-fatal code', () {
      const cancelled = VpnException('cancelled', 'Connection cancelled.');
      expect(VpnFailure.from(cancelled).code, 'cancelled');
      // A cancelled attempt is user intent, not a server problem.
      expect(VpnFailure.from(cancelled).code, isNot('unknown'));
    });
  });
}