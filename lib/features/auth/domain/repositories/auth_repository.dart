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

  Future<void> signOut();

  Session? get currentSession;

  Stream<AuthState> get onAuthStateChange;
}
