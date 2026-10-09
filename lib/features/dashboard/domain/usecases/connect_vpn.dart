import 'package:yoopn/core/utils/app_logger.dart';
import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class ConnectVpnUseCase {
  const ConnectVpnUseCase(this._repository);

  final VpnRepository _repository;

  Future<void> call(VpnServer server) {
    AppLogger.i('VPN', 'usecase.connect → ${server.id} (${server.ip})');
    return _repository.connect(server);
  }
}