import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class UpdateDisplayNameUseCase {
  const UpdateDisplayNameUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUserEntity?> call({required String displayName}) {
    return _repository.updateDisplayName(displayName: displayName);
  }
}
