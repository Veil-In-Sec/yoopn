import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class GetVpnServersUseCase {
  const GetVpnServersUseCase(this._repository);

  final VpnRepository _repository;

  Future<List<VpnServer>> call({bool forceRefresh = false}) =>
      _repository.getServers(forceRefresh: forceRefresh);
}
