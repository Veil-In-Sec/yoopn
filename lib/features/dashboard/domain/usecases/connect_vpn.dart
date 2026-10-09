import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class ConnectVpnUseCase {
  const ConnectVpnUseCase(this._repository);

  final VpnRepository _repository;

  Future<void> call(VpnServer server) => _repository.connect(server);
}
