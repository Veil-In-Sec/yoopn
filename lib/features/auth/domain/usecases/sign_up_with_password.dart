import 'package:yoopn/core/utils/app_logger.dart';
import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpWithPasswordUseCase {
  final AuthRepository repository;

  const SignUpWithPasswordUseCase(this.repository);

  Future<AuthUserEntity?> call({
    required String email,
    required String password,
  }) {
    AppLogger.d('AUTH', 'usecase.signUpWithPassword email=${AppLogger.maskEmail(email)}');
    return repository.signUpWithPassword(email: email, password: password);
  }
}