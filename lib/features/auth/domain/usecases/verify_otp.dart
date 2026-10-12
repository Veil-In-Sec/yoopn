import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository repository;

  const VerifyOtpUseCase(this.repository);

  Future<AuthUserEntity?> call({required String email, required String otp}) =>
      repository.verifyOtp(email: email, otp: otp);
}