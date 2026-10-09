import 'package:yoopn/core/utils/app_logger.dart';
import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class GetVpnServersUseCase {
  const GetVpnServersUseCase(this._repository);

  final VpnRepository _repository;

  Future<List<VpnServer>> call({bool forceRefresh = false}) {
    AppLogger.d('VPN', 'usecase.getServers forceRefresh=$forceRefresh');
    return _repository.getServers(forceRefresh: forceRefresh);
  }
}