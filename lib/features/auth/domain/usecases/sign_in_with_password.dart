import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInWithPasswordUseCase {
  final AuthRepository repository;

  const SignInWithPasswordUseCase(this.repository);

  Future<AuthUserEntity?> call({
    required String email,
    required String password,
  }) =>
      repository.signInWithPassword(email: email, password: password);
}