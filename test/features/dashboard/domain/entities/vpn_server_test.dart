import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/domain/entities/vpn_server.dart';

const String _validConfigB64 =
    'Y2xpZW50CmRldiB0dW4KcHJvdG8gdWRwCnJlbW90ZSAxLjIuMy40IDExOTQ=';

void main() {
  group('VpnServer id + matching', () {
    const relay = VpnServer(
      name: 'Japan',
      flag: '🇯🇵',
      hostName: 'public-vpn-119',
      ip: '219.126.35.11',
      openVpnConfig: _validConfigB64,
    );

    test('id prefers hostName so it stays stable across refreshes', () {
      expect(relay.id, 'public-vpn-119');
    });

    test('fallback servers fall back to the country name', () {
      const fallback = VpnServer(name: 'Germany', flag: '🇩🇪');
      expect(fallback.id, 'Germany');
      expect(fallback.isVpnGate, isFalse);
    });

    test('matchesId accepts hostName, ip, name and id', () {
      expect(relay.matchesId('public-vpn-119'), isTrue);
      expect(relay.matchesId('219.126.35.11'), isTrue);
      expect(relay.matchesId('Japan'), isTrue);
      expect(relay.matchesId('nope'), isFalse);
    });
  });

  group('VpnServer config decoding', () {
    test('decodes base64 config, tolerating whitespace', () {
      final padded = '\n  $_validConfigB64 \n';
      final server = VpnServer(
        name: 'Japan',
        flag: '🇯🇵',
        hostName: 'public-vpn-119',
        ip: '219.126.35.11',
        openVpnConfig: padded,
      );

      expect(server.decodedOpenVpnConfig, contains('client'));
      expect(server.decodedOpenVpnConfig, contains('remote 1.2.3.4 1194'));
    });

    test('returns empty string for undecodable config', () {
      const broken = VpnServer(
        name: 'Japan',
        flag: '🇯🇵',
        hostName: 'public-vpn-119',
        ip: '1.2.3.4',
        openVpnConfig: '!!!not-base64!!!',
      );
      expect(broken.decodedOpenVpnConfig, isEmpty);
    });
  });

  group('VpnServer display text', () {
    test('formats speed across Kbps / Mbps / Gbps', () {
      VpnServer withSpeed(int bps) =>
          VpnServer(name: 'X', flag: '🌐', hostName: 'h', ip: 'i', speed: bps);

      expect(withSpeed(0).speedText, '—');
      expect(withSpeed(500_000).speedText, '500 Kbps');
      expect(withSpeed(209_800_000).speedText, '209.8 Mbps');
      expect(withSpeed(2_000_000_000).speedText, '2.00 Gbps');
    });

    test('formats ping and hides the unknown case', () {
      const known = VpnServer(name: 'X', flag: '🌐', ping: 11);
      const unknown = VpnServer(name: 'X', flag: '🌐');
      expect(known.pingText, '11 ms');
      expect(unknown.pingText, '—');
    });
  });

  group('flagFromCountryCode', () {
    test('maps ISO codes to flag emoji', () {
      expect(VpnServer.flagFromCountryCode('JP'), '🇯🇵');
      expect(VpnServer.flagFromCountryCode('us'), '🇺🇸');
      expect(VpnServer.flagFromCountryCode('de'), '🇩🇪');
    });

    test('falls back to a globe for invalid input', () {
      expect(VpnServer.flagFromCountryCode(''), '🌐');
      expect(VpnServer.flagFromCountryCode('XYZ'), '🌐');
      expect(VpnServer.flagFromCountryCode('12'), '🌐');
    });
  });

  group('toJson round-trip', () {
    test('preserves identity through the caching layer', () {
      const server = VpnServer(
        name: 'Japan',
        flag: '🇯🇵',
        hostName: 'public-vpn-119',
        ip: '219.126.35.11',
        score: 9000,
        ping: 11,
        speed: 209_800_000,
        countryShort: 'JP',
        countryLong: 'Japan',
        sessions: 42,
        uptime: 3600,
        openVpnConfig: _validConfigB64,
      );

      final restored = VpnServer(
        hostName: server.toJson()['hostName'] as String,
        name: server.toJson()['name'] as String,
        flag: server.toJson()['flag'] as String,
        ip: server.toJson()['ip'] as String,
        openVpnConfig: server.toJson()['openVpnConfig'] as String,
      );

      expect(restored.id, server.id);
      expect(restored.isVpnGate, isTrue);
      expect(restored, server);
    });
  });
}