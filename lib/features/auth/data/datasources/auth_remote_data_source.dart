import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yoopn/core/config/google_config.dart';
import 'package:yoopn/core/config/supabase_config.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import '../models/auth_credentials_model.dart';
import '../models/auth_user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthUserModel?> signInWithPassword(AuthCredentialsModel credentials);
  Future<AuthUserModel?> signUpWithPassword(AuthCredentialsModel credentials);
  Future<bool> signInWithGoogle();
  Future<void> signInWithOtp(String email);
  Future<AuthUserModel?> verifyOtp(String email, String otp);
  Future<AuthUserModel?> updateEmail(String email);
  Future<AuthUserModel?> updatePassword(String password);
  Future<AuthUserModel?> updateDisplayName(String displayName);
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
    final masked = AppLogger.maskEmail(credentials.email);
    AppLogger.i('AUTH', 'remote.signInWithPassword email=$masked');
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: credentials.email.trim(),
        password: credentials.password.trim(),
      );
      AppLogger.i('AUTH', 'remote.signInWithPassword ok user=${response.user?.email} session=${response.session != null}');
      if (response.user != null) {
        return AuthUserModel.fromSupabaseUser(response.user!);
      }
      AppLogger.w('AUTH', 'remote.signInWithPassword null user');
      return null;
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.signInWithPassword failed email=$masked', e, st);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> signUpWithPassword(
      AuthCredentialsModel credentials) async {
    final masked = AppLogger.maskEmail(credentials.email);
    AppLogger.i('AUTH', 'remote.signUpWithPassword email=$masked');
    try {
      final response = await _supabaseClient.auth.signUp(
        email: credentials.email.trim(),
        password: credentials.password.trim(),
      );
      AppLogger.i('AUTH', 'remote.signUp ok user=${response.user?.email} session=${response.session != null}');
      if (response.user != null) {
        return AuthUserModel.fromSupabaseUser(response.user!);
      }
      AppLogger.w('AUTH', 'remote.signUp null user (email confirmation pending?)');
      return null;
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.signUp failed email=$masked', e, st);
      rethrow;
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    AppLogger.i(
      'AUTH',
      'remote.signInWithGoogle mode=${GoogleConfig.nativeConfigured ? 'native-primary + browser fallback' : 'system-browser OAuth'}',
    );

    // 1) NATIVE one-tap (Credential Manager bottom sheet listing the device's
    //    Google accounts — no browser, no deep link). Attempted only when the
    //    owner-configured GOOGLE_WEB_CLIENT_ID is present; Android-only; on
    //    any failure we degrade gracefully to the browser flow below so the
    //    sign-in never dead-ends.
    if (GoogleConfig.nativeConfigured) {
      try {
        final ok = await _signInWithGoogleNative();
        return ok;
      } on GoogleSignInException catch (e, st) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          // User backed out of the account sheet — do NOT then shove them
          // into a browser flow they didn't ask for.
          AppLogger.e('AUTH', 'remote.signInWithGoogle native canceled by user', e, st);
          rethrow;
        }
        AppLogger.w('AUTH', 'remote.signInWithGoogle native failed (${e.code.name}) — falling back to browser flow');
      } catch (e, st) {
        AppLogger.e('AUTH', 'remote.signInWithGoogle native unexpected — falling back to browser flow', e, st);
      }
    }

    // 2) FALLBACK — system-browser OAuth (works with zero Google Cloud
    //    client-side config): after Google consent, Supabase redirects to
    //    the custom scheme `io.supabase.yoopn://login-callback`, which only
    //    resolves back to the app when the OS dispatches it — in-app browser
    //    tabs swallow custom-scheme navigations, so the callback never
    //    arrives. supabase_flutter completes the PKCE exchange automatically
    //    from the deep link (SupabaseAuth + app_links).
    try {
      final ok = await _supabaseClient.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      AppLogger.i('AUTH', 'remote.signInWithGoogle launched=$ok (system browser)');
      return ok;
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.signInWithGoogle failed', e, st);
      rethrow;
    }
  }

  /// Native Credential Manager one-tap (google_sign_in 7.x).
  ///
  /// Official Supabase pattern: the WEB client ID is passed as
  /// `serverClientId`; Google mints an ID token directly into the app (no
  /// browser, no deep link) and Supabase validates it with
  /// `signInWithIdToken`, returning a real session synchronously (the
  /// browser path instead waits for the deep-link callback).
  Future<bool> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: GoogleConfig.webClientId);

    final googleUser = await googleSignIn.authenticate();

    const scopes = ['email', 'profile'];
    final authorization =
        await googleUser.authorizationClient.authorizationForScopes(scopes) ??
        await googleUser.authorizationClient.authorizeScopes(scopes);

    final idToken = googleUser.authentication.idToken;
    AppLogger.i('AUTH', 'remote.signInWithGoogle native idToken=${idToken != null}');
    if (idToken == null) {
      throw AuthException('No ID Token found.');
    }

    final response = await _supabaseClient.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
    AppLogger.i('AUTH', 'remote.signInWithGoogle native ok session=${response.session != null}');
    return response.session != null;
  }

  @override
  Future<void> signInWithOtp(String email) async {
    AppLogger.i('AUTH', 'remote.signInWithOtp email=${AppLogger.maskEmail(email)}');
    try {
      await _supabaseClient.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
      );
      AppLogger.i('AUTH', 'remote.signInWithOtp sent');
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.signInWithOtp failed', e, st);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> verifyOtp(String email, String otp) async {
    AppLogger.i('AUTH', 'remote.verifyOtp email=${AppLogger.maskEmail(email)} otpLen=${otp.trim().length}');
    try {
      final response = await _supabaseClient.auth.verifyOTP(
        email: email.trim(),
        token: otp.trim(),
        type: OtpType.email,
      );
      AppLogger.i('AUTH', 'remote.verifyOtp ok user=${response.user?.email}');
      if (response.user != null) {
        return AuthUserModel.fromSupabaseUser(response.user!);
      }
      return null;
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.verifyOtp failed', e, st);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> updateEmail(String email) async {
    final masked = AppLogger.maskEmail(email);
    AppLogger.i('AUTH', 'remote.updateEmail email=$masked');
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(email: email.trim()),
      );
      AppLogger.i('AUTH', 'remote.updateEmail ok, confirmation sent');
      return response.user == null
          ? null
          : AuthUserModel.fromSupabaseUser(response.user!);
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.updateEmail failed email=$masked', e, st);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> updatePassword(String password) async {
    AppLogger.i('AUTH', 'remote.updatePassword');
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(password: password.trim()),
      );
      AppLogger.i('AUTH', 'remote.updatePassword ok');
      return response.user == null
          ? null
          : AuthUserModel.fromSupabaseUser(response.user!);
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.updatePassword failed', e, st);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> updateDisplayName(String displayName) async {
    AppLogger.i('AUTH', 'remote.updateDisplayName');
    try {
      final response = await _supabaseClient.auth.updateUser(
        UserAttributes(
          data: {'full_name': displayName.trim(), 'display_name': displayName.trim()},
        ),
      );
      AppLogger.i('AUTH', 'remote.updateDisplayName ok');
      return response.user == null
          ? null
          : AuthUserModel.fromSupabaseUser(response.user!);
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.updateDisplayName failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.i('AUTH', 'remote.signOut');
    try {
      await _supabaseClient.auth.signOut();
      AppLogger.i('AUTH', 'remote.signOut done');
    } catch (e, st) {
      AppLogger.e('AUTH', 'remote.signOut failed', e, st);
      rethrow;
    }
  }

  @override
  Session? get currentSession => _supabaseClient.auth.currentSession;

  @override
  Stream<AuthState> get onAuthStateChange =>
      _supabaseClient.auth.onAuthStateChange;
}
