import '../repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository repository;

  const SignInWithGoogleUseCase(this.repository);

  Future<bool> call() => repository.signInWithGoogle();
}