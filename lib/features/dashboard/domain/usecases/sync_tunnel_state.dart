import '../repositories/vpn_repository.dart';

class SyncTunnelStateUseCase {
  const SyncTunnelStateUseCase(this._repository);

  final VpnRepository _repository;

  Future<bool> call() => _repository.syncTunnelState();
}
