import '../entities/vpn_server.dart';
import '../repositories/vpn_repository.dart';

class SearchServersUseCase {
  const SearchServersUseCase(this._repository);

  final VpnRepository _repository;

  Future<List<VpnServer>> call(String query) =>
      _repository.searchServers(query);
}