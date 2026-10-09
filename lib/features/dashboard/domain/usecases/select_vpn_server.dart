import 'package:yoopn/core/utils/app_logger.dart';
import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class SelectVpnServerUseCase {
  const SelectVpnServerUseCase(this._repository);

  final VpnRepository _repository;

  VpnServer? call(String name) {
    AppLogger.d('VPN', 'usecase.selectServer id=$name');
    return _repository.findServer(name);
  }
}