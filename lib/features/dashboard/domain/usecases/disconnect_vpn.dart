import 'package:yoopn/core/utils/app_logger.dart';
import '../repositories/vpn_repository.dart';

class DisconnectVpnUseCase {
  const DisconnectVpnUseCase(this._repository);

  final VpnRepository _repository;

  Future<void> call() {
    AppLogger.i('VPN', 'usecase.disconnect');
    return _repository.disconnect();
  }
}