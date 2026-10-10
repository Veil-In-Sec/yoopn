import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';

/// Guards the instant-first-launch path: the snapshot baked by
/// `dart run tool/fetch_snapshot.dart` must ship inside the asset bundle
/// (pubspec `assets:`) and parse into connectable relays.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled snapshot parses into usable relays', () async {
    final raw = await rootBundle.loadString('assets/servers_snapshot.json');
    expect(raw.isNotEmpty, isTrue);

    final servers = VpnServerModel.serversFromJsonString(raw);
    expect(servers, isNotEmpty);
    expect(servers.length, greaterThan(10));
    // Every entry must carry an OpenVPN config or it is as useless as the
    // static mocks the snapshot exists to replace.
    expect(servers.every((s) => s.isVpnGate), isTrue);
  });
}
