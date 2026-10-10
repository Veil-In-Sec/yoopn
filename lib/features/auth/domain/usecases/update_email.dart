import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class UpdateEmailUseCase {
  const UpdateEmailUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthUserEntity?> call({required String email}) {
    return _repository.updateEmail(email: email);
  }
}
