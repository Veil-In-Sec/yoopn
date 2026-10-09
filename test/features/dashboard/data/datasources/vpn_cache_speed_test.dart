import 'package:flutter_test/flutter_test.dart';
import 'package:yoopn/features/dashboard/data/datasources/speed_test_data_source.dart';
import 'package:yoopn/features/dashboard/data/datasources/vpn_local_data_source.dart';
import 'package:yoopn/features/dashboard/data/models/vpn_server_model.dart';

const _sampleCsv = '''
*vpn_servers
#HostName,IP,Score,Ping,Speed,CountryLong,CountryShort,NumVpnSessions,Uptime,TotalUsers,TotalTraffic,LogType,Operator,Message,OpenVPN_ConfigData_Base64
public-vpn-119,219.100.37.113,2846127,11,209823681,Japan,JP,107,1,1,1,2weeks,Op,Msg,QUJDRA==
public-vpn-202,1.2.3.4,100,5,1000000,United States,US,5,1,1,1,2weeks,Op,Msg,RUJDRA==
''';

void main() {
  test('sqflite contract: cache -> load -> best -> search (in-memory)', () async {
    final local = InMemoryVpnLocalDataSource();
    final json = VpnServerModel.csvToJson(_sampleCsv);

    await local.cacheServers(json);

    final cached = await local.loadCachedServers();
    expect(cached.length, 2);

    // Best = highest score among reachable (public-vpn-119).
    final best = await local.loadBestServer();
    expect(best?.hostName, 'public-vpn-119');

    final search = await local.loadCachedServers(query: 'united');
    expect(search.length, 1);
    expect(search.first.hostName, 'public-vpn-202');

    expect(await local.lastCachedAt(), isNotNull);

    await local.clear();
    expect(await local.loadCachedServers(), isEmpty);
  });

  test('speed mbps helper converts bytes/time correctly', () {
    // 10 MB in 8 s -> 10 Mbps.
    expect(
      LiveSpeedTestDataSource.mbps(10 * 1024 * 1024, 8 * 1000000),
      closeTo(10.48576, 0.001),
    );
    expect(LiveSpeedTestDataSource.mbps(0, 1000), 0);
    expect(LiveSpeedTestDataSource.mbps(1000, 0), 0);
  });
}
