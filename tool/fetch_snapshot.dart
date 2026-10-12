import 'dart:convert';
import 'dart:io';

import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';

Future<void> main() async {
  const endpoint = 'https://www.vpngate.net/api/iphone/';
  stdout.writeln('fetching $endpoint ...');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(endpoint));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final csv = await response.transform(utf8.decoder).join();
    stdout.writeln('downloaded ${csv.length} chars');
    final json = VpnServerModel.csvToJson(csv);
    stdout.writeln('parsed ${json.length} rows');
    final servers = VpnServerModel.serversFromJson(json);
    stdout.writeln('usable servers: ${servers.length}');
    if (servers.isEmpty) {
      throw StateError('refusing to write an empty snapshot');
    }
    final out = File('assets/servers_snapshot.json');
    await out.writeAsString(jsonEncode(json));
    stdout.writeln('wrote ${out.path} (${await out.length()} bytes)');
  } finally {
    client.close();
  }
}
