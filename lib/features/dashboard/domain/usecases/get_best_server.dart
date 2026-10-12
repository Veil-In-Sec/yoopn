import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class GetBestServerUseCase {
  const GetBestServerUseCase(this._repository);

  final VpnRepository _repository;

  Future<VpnServer?> call() => _repository.getBestServer();
}