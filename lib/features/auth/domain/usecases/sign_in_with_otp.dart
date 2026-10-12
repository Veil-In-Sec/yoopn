import '../repositories/auth_repository.dart';

class SignInWithOtpUseCase {
  final AuthRepository repository;

  const SignInWithOtpUseCase(this.repository);

  Future<void> call({required String email}) =>
      repository.signInWithOtp(email: email);
}