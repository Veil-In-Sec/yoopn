import 'package:yoopn/core/utils/app_logger.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository repository;

  const SignOutUseCase(this.repository);

  Future<void> call() {
    AppLogger.d('AUTH', 'usecase.signOut');
    return repository.signOut();
  }
}