import '../../domain/entities/vpn_server.dart';
import '../../domain/repositories/vpn_repository.dart';
import '../datasources/vpn_data_source.dart';

class VpnRepositoryImpl implements VpnRepository {
  const VpnRepositoryImpl({required this.dataSource});

  final VpnDataSource dataSource;

  @override
  Future<void> connect(VpnServer server) {
    final availableServer = findServer(server.name);
    if (availableServer == null) {
      throw ArgumentError.value(server.name, 'server', 'Unknown VPN server');
    }
    return dataSource.connect(availableServer);
  }

  @override
  Future<void> disconnect() => dataSource.disconnect();

  @override
  VpnServer? findServer(String name) => dataSource.findServer(name);
}
