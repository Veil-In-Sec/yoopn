import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';

void main() {
  const sampleCsv = '''
*vpn_servers
#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,OpenVPN_ConfigData_Base64
public-vpn-119,219.100.37.113,2846127,11,209823681,Japan,JP,107,550390293,34247209,1668878344155156,2weeks,Op,Msg,QUJDRA==
public-vpn-202,1.2.3.4,100,20,1000000,United States,US,5,100,10,1000,2weeks,Op,Hello, world, with, commas,RUJDRA==
bad-line,only,two,cols
empty-config,5.6.7.8,10,10,100,Germany,DE,1,10,1,100,2weeks,Op,Msg,
''';

  test('stage 1: CSV -> JSON maps with tolerant Message commas', () {
    final json = VpnServerModel.csvToJson(sampleCsv);

    // 2 valid rows: plain + comma-in-message. Bad + empty-config skipped.
    expect(json.length, 2);

    final first = json.firstWhere((e) => e['hostName'] == 'public-vpn-119');
    expect(first['ip'], '219.100.37.113');
    expect(first['score'], 2846127);
    expect(first['ping'], 11);
    expect(first['countryLong'], 'Japan');
    expect(first['countryShort'], 'JP');
    expect(first['name'], 'Japan');
    expect(first['flag'], '🇯🇵');
    expect(first['openVpnConfig'], 'QUJDRA==');

    final second = json.firstWhere((e) => e['hostName'] == 'public-vpn-202');
    expect(second['message'], 'Hello, world, with, commas');

    // JSON must round-trip through jsonEncode for caching.
    expect(() => jsonEncode(json), returnsNormally);
  });

  test('stage 2: JSON -> typed servers sorted by score desc', () {
    final json = VpnServerModel.csvToJson(sampleCsv);
    final servers = VpnServerModel.serversFromJson(json);

    expect(servers.length, 2);
    // Higher score first.
    expect(servers.first.hostName, 'public-vpn-119');
    expect(servers.first.isVpnGate, isTrue);
    expect(servers.first.speedText, isNotEmpty);
    expect(servers.first.decodedOpenVpnConfig, isNotEmpty);

    // Entity toJson pairs with fromJson.
    final roundTrip = VpnServerModel.fromJson(servers.first.toJson());
    expect(roundTrip, servers.first);
  });

  test('stage 3: parseCsv chains CSV -> JSON -> servers', () {
    final servers = VpnServerModel.parseCsv(sampleCsv);
    expect(servers.length, 2);

    final fromString = VpnServerModel.serversFromJsonString(
      VpnServerModel.csvToJsonString(sampleCsv),
    );
    expect(fromString.length, 2);
    expect(fromString.first.hostName, servers.first.hostName);
  });
}
