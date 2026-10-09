import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/config/supabase_config.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthUserModel?> signInWithPassword(AuthCredentialsModel credentials);
  Future<AuthUserModel?> signUpWithPassword(AuthCredentialsModel credentials);
  Future<bool> signInWithGoogle();
  Future<void> signInWithOtp(String email);
  Future<AuthUserModel?> verifyOtp(String email, String otp);
  Future<void> signOut();
  Session? get currentSession;
  Stream<AuthState> get onAuthStateChange;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _supabaseClient;

  AuthRemoteDataSourceImpl({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  @override
  Future<AuthUserModel?> signInWithPassword(
      AuthCredentialsModel credentials) async {
    final response = await _supabaseClient.auth.signInWithPassword(
      email: credentials.email.trim(),
      password: credentials.password.trim(),
    );
    if (response.user != null) {
      return AuthUserModel(
        id: response.user!.id.hashCode,
        email: response.user!.email ?? '',
      );
    }
    return null;
  }

  @override
  Future<AuthUserModel?> signUpWithPassword(
      AuthCredentialsModel credentials) async {
    final response = await _supabaseClient.auth.signUp(
      email: credentials.email.trim(),
      password: credentials.password.trim(),
    );
    if (response.user != null) {
      return AuthUserModel(
        id: response.user!.id.hashCode,
        email: response.user!.email ?? '',
      );
    }
    return null;
  }

  @override
  Future<bool> signInWithGoogle() async {
    return await _supabaseClient.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signInWithOtp(String email) async {
    await _supabaseClient.auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
    );
  }

  @override
  Future<AuthUserModel?> verifyOtp(String email, String otp) async {
    final response = await _supabaseClient.auth.verifyOTP(
      email: email.trim(),
      token: otp.trim(),
      type: OtpType.email,
    );
    if (response.user != null) {
      return AuthUserModel(
        id: response.user!.id.hashCode,
        email: response.user!.email ?? '',
      );
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Session? get currentSession => _supabaseClient.auth.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange =>
      _supabaseClient.auth.onAuthStateChange;
}
