import '../repositories/vpn_repository.dart';

class WatchConnectionDetailUseCase {
  const WatchConnectionDetailUseCase(this._repository);

  final VpnRepository _repository;

  Stream<String> call() => _repository.connectionDetailStream;

  String lastDetail() {
    try {
      return _repository.lastConnectionDetail;
    } catch (_) {
      return '';
    }
  }
}
