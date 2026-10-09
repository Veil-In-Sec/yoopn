import '../repositories/auth_repository.dart';
import 'sign_in_with_google.dart';
import 'sign_in_with_otp.dart';
import 'sign_in_with_password.dart';
import 'sign_out.dart';
import 'sign_up_with_password.dart';
import 'verify_otp.dart';

class AuthUseCases {
  final SignInWithPasswordUseCase signInWithPassword;
  final SignUpWithPasswordUseCase signUpWithPassword;
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignInWithOtpUseCase signInWithOtp;
  final VerifyOtpUseCase verifyOtp;
  final SignOutUseCase signOut;

  const AuthUseCases({
    required this.signInWithPassword,
    required this.signUpWithPassword,
    required this.signInWithGoogle,
    required this.signInWithOtp,
    required this.verifyOtp,
    required this.signOut,
  });

  factory AuthUseCases.fromRepository(AuthRepository repository) {
    return AuthUseCases(
      signInWithPassword: SignInWithPasswordUseCase(repository),
      signUpWithPassword: SignUpWithPasswordUseCase(repository),
      signInWithGoogle: SignInWithGoogleUseCase(repository),
      signInWithOtp: SignInWithOtpUseCase(repository),
      verifyOtp: VerifyOtpUseCase(repository),
      signOut: SignOutUseCase(repository),
    );
  }
}
