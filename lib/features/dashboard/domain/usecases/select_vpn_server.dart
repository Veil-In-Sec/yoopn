import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class SelectVpnServerUseCase {
  const SelectVpnServerUseCase(this._repository);

  final VpnRepository _repository;

  VpnServer? call(String name) => _repository.findServer(name);
}
