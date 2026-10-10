import '../repositories/vpn_repository.dart';

/// Adopt a live OS tunnel that outlived the app process.
/// True when the engine reports a connected tunnel.
class SyncTunnelStateUseCase {
  const SyncTunnelStateUseCase(this._repository);

  final VpnRepository _repository;

  Future<bool> call() => _repository.syncTunnelState();
}
