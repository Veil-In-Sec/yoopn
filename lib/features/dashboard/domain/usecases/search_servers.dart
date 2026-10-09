import 'package:yoopn/core/utils/app_logger.dart';
import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class SearchServersUseCase {
  const SearchServersUseCase(this._repository);

  final VpnRepository _repository;

  Future<List<VpnServer>> call(String query) {
    AppLogger.d('VPN', 'usecase.search query="$query"');
    return _repository.searchServers(query);
  }
}