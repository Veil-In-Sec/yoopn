import '../repositories/vpn_repository.dart';

class DisconnectVpnUseCase {
  const DisconnectVpnUseCase(this._repository);

  final VpnRepository _repository;

  Future<void> call() => _repository.disconnect();
}
