import 'package:yoopn/core/utils/app_logger.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository repository;

  const SignInWithGoogleUseCase(this.repository);

  Future<bool> call() {
    AppLogger.d('AUTH', 'usecase.signInWithGoogle');
    return repository.signInWithGoogle();
  }
}