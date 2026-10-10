import '../repositories/vpn_repository.dart';

/// Live engine sub-stage texts while connecting ('' when idle).
class WatchConnectionDetailUseCase {
  const WatchConnectionDetailUseCase(this._repository);

  final VpnRepository _repository;

  Stream<String> call() => _repository.connectionDetailStream;

  /// Freshest known sub-stage without waiting on the stream (see
  /// [VpnRepository.lastConnectionDetail]). Falls back to ''.
  String lastDetail() {
    try {
      return _repository.lastConnectionDetail;
    } catch (_) {
      return '';
    }
  }
}
