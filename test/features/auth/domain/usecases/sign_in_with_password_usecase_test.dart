import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/features/auth/domain/entities/auth_user_entity.dart';
import 'package:yoopn/features/auth/domain/repositories/auth_repository.dart';
import 'package:yoopn/features/auth/domain/usecases/sign_in_with_password.dart';

class _FakeAuthRepository implements AuthRepository {
  bool called = false;

  @override
  Future<AuthUserEntity?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    called = true;
    return const AuthUserEntity(id: 7, email: 'user@example.com');
  }

  @override
  Future<AuthUserEntity?> signUpWithPassword({
    required String email,
    required String password,
  }) async => null;

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<void> signInWithOtp({required String email}) async {}

  @override
  Future<AuthUserEntity?> verifyOtp({
    required String email,
    required String otp,
  }) async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUserEntity?> updateEmail({required String email}) async => null;

  @override
  Future<AuthUserEntity?> updatePassword({required String password}) async =>
      null;

  @override
  Future<AuthUserEntity?> updateDisplayName({
    required String displayName,
  }) async =>
      null;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

void main() {
  test('SignInWithPasswordUseCase delegates to repository', () async {
    final repository = _FakeAuthRepository();
    final useCase = SignInWithPasswordUseCase(repository);

    final result = await useCase(email: 'user@example.com', password: '123456');

    expect(result?.email, 'user@example.com');
    expect(repository.called, isTrue);
  });
}
