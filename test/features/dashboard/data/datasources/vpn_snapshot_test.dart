import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled snapshot parses into usable relays', () async {
    final raw = await rootBundle.loadString('assets/servers_snapshot.json');
    expect(raw.isNotEmpty, isTrue);

    final servers = VpnServerModel.serversFromJsonString(raw);
    expect(servers, isNotEmpty);
    expect(servers.length, greaterThan(10));
    expect(servers.every((s) => s.isVpnGate), isTrue);
  });
}
