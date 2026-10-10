import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUserEntity?> call({required String password}) {
    return _repository.updatePassword(password: password);
  }
}
