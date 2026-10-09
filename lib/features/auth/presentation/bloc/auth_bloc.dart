import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:yoopn/core/config/supabase_config.dart';
import 'package:yoopn/core/utils/app_validators.dart';
import 'package:yoopn/core/utils/internet_connections.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final supabase.SupabaseClient _supabaseClient;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthBloc({supabase.SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? supabase.Supabase.instance.client,
        super(const AuthState()) {
    on<AuthEmailChanged>(_onEmailChanged);
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthPasswordSubmitted>(_onPasswordSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthGoogleSubmitted>(_onGoogleSubmitted);
    on<AuthSessionChanged>(_onSessionChanged);
    on<AuthSignOutSubmitted>(_onSignOutSubmitted);

    _authSubscription = _supabaseClient.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null &&
          (data.event == supabase.AuthChangeEvent.signedIn ||
              data.event == supabase.AuthChangeEvent.tokenRefreshed ||
              data.event == supabase.AuthChangeEvent.initialSession)) {
        add(AuthSessionChanged(session));
      } else if (data.event == supabase.AuthChangeEvent.signedOut) {
        add(const AuthSessionChanged(null));
      }
    });
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  void _onEmailChanged(
    AuthEmailChanged event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(email: event.email));
  }

  void _onSessionChanged(
    AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.session != null) {
      emit(state.copyWith(
        status: AuthStatus.success,
        session: event.session,
      ));
    } else {
      emit(state.copyWith(
        status: AuthStatus.initial,
        session: null,
      ));
    }
  }

  void _onEmailSubmitted(
    AuthEmailSubmitted event,
    Emitter<AuthState> emit,
  ) {
    final validationError = AppValidators.validateEmail(state.email);
    if (validationError != null) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: validationError,
      ));
      return;
    }

    emit(state.copyWith(
      status: AuthStatus.emailSubmitted,
      errorMsg: null,
      message: null,
    ));
  }

  Future<void> _onPasswordSubmitted(
    AuthPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final password = event.password.trim();
    if (password.length < 6) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Password must be at least 6 characters',
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, errorMsg: null, message: null));

    if (!await InternetUtils.isConnected()) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please connect to the internet!',
      ));
      return;
    }

    try {
      // 1. Try to sign in first
      final response = await _supabaseClient.auth.signInWithPassword(
        email: state.email.trim(),
        password: password,
      );

      if (response.session != null) {
        emit(state.copyWith(
          status: AuthStatus.success,
          session: response.session,
        ));
        return;
      }
    } on supabase.AuthException catch (e) {
      final errorMsgLower = e.message.toLowerCase();
      // If error indicates user not found or invalid login credentials, attempt sign up automatically
      if (errorMsgLower.contains('invalid') ||
          errorMsgLower.contains('user not found') ||
          errorMsgLower.contains('credentials') ||
          e.code == 'invalid_credentials') {
        try {
          final signUpResponse = await _supabaseClient.auth.signUp(
            email: state.email.trim(),
            password: password,
          );

          if (signUpResponse.session != null) {
            emit(state.copyWith(
              status: AuthStatus.success,
              session: signUpResponse.session,
            ));
            return;
          } else if (signUpResponse.user != null) {
            emit(state.copyWith(
              status: AuthStatus.otpSent,
              message: 'Account created! Please check your email to confirm registration if required.',
            ));
            return;
          }
        } on supabase.AuthException catch (signUpError) {
          if (signUpError.message.toLowerCase().contains('already registered') ||
              signUpError.message.toLowerCase().contains('already exists')) {
            emit(state.copyWith(
              status: AuthStatus.failure,
              errorMsg: 'Incorrect password for this existing account.',
            ));
            return;
          }
          emit(state.copyWith(
            status: AuthStatus.failure,
            errorMsg: signUpError.message,
          ));
          return;
        } catch (signUpError) {
          emit(state.copyWith(
            status: AuthStatus.failure,
            errorMsg: signUpError.toString(),
          ));
          return;
        }
      }

      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.message,
      ));
      return;
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.toString(),
      ));
      return;
    }
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (event.otp.trim().isEmpty) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please enter the verification code',
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading, errorMsg: null, message: null));

    if (!await InternetUtils.isConnected()) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please connect to the internet!',
      ));
      return;
    }

    try {
      final response = await _supabaseClient.auth.verifyOTP(
        email: state.email.trim(),
        token: event.otp.trim(),
        type: supabase.OtpType.email,
      );
      if (response.session != null) {
        emit(state.copyWith(
          status: AuthStatus.success,
          session: response.session,
        ));
      } else {
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMsg: 'Verification failed. Please check the code and try again.',
        ));
      }
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.toString(),
      ));
    }
  }

  Future<void> _onGoogleSubmitted(
    AuthGoogleSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMsg: null, message: null));

    if (!await InternetUtils.isConnected()) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please connect to the internet!',
      ));
      return;
    }

    try {
      final launched = await _supabaseClient.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
        authScreenLaunchMode: supabase.LaunchMode.externalApplication,
      );
      if (!launched) {
        emit(state.copyWith(
          status: AuthStatus.failure,
          errorMsg: 'Failed to open browser for Google authentication.',
        ));
      }
    } on supabase.AuthException catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.toString(),
      ));
    }
  }

  Future<void> _onSignOutSubmitted(
    AuthSignOutSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _supabaseClient.auth.signOut();
      emit(const AuthState(status: AuthStatus.initial));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: e.toString(),
      ));
    }
  }
}
