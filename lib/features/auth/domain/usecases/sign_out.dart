import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository repository;

  const SignOutUseCase(this.repository);

  Future<void> call() => repository.signOut();
}