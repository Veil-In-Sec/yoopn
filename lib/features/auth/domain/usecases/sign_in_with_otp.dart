import 'package:yoopn/core/utils/app_logger.dart';
import '../repositories/auth_repository.dart';

class SignInWithOtpUseCase {
  final AuthRepository repository;

  const SignInWithOtpUseCase(this.repository);

  Future<void> call({required String email}) {
    AppLogger.d('AUTH', 'usecase.signInWithOtp email=${AppLogger.maskEmail(email)}');
    return repository.signInWithOtp(email: email);
  }
}