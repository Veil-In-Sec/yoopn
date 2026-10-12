import 'package:supabase_flutter/supabase_flutter.dart';
import '../entities/auth_user_entity.dart';

abstract class AuthRepository {
  Future<AuthUserEntity?> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthUserEntity?> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<bool> signInWithGoogle();

  Future<void> signInWithOtp({required String email});

  Future<AuthUserEntity?> verifyOtp({
    required String email,
    required String otp,
  });

  Future<AuthUserEntity?> updateEmail({required String email});

  Future<AuthUserEntity?> updatePassword({required String password});

  Future<AuthUserEntity?> updateDisplayName({required String displayName});

  Future<void> signOut();

  AuthUserEntity mapSessionUser(Session session);

  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;
}
