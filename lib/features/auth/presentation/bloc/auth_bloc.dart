import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:yoopn/core/telemetry/supabase_telemetry.dart';
import 'package:yoopn/core/utils/app_logger.dart';
import 'package:yoopn/features/auth/presentation/helper/friendly_auth_error.dart';
import 'package:yoopn/core/utils/app_validators.dart';
import 'package:yoopn/core/utils/internet_connections.dart';
import 'package:yoopn/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:yoopn/features/auth/data/models/auth_user_model.dart';
import 'package:yoopn/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:yoopn/features/auth/domain/entities/auth_user_entity.dart';
import 'package:yoopn/features/auth/domain/repositories/auth_repository.dart';
import 'package:yoopn/features/auth/domain/usecases/auth_use_cases.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;
  late final AuthUseCases _authUseCases;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthBloc({AuthRepository? repository, AuthUseCases? useCases})
    : _repository =
          repository ??
          AuthRepositoryImpl(remoteDataSource: AuthRemoteDataSourceImpl()),
      super(const AuthState()) {
    _authUseCases = useCases ?? AuthUseCases.fromRepository(_repository);

    on<AuthEmailChanged>(_onEmailChanged);
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthPasswordSubmitted>(_onPasswordSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthGoogleSubmitted>(_onGoogleSubmitted);
    on<AuthSessionChanged>(_onSessionChanged);
    on<AuthSignOutSubmitted>(_onSignOutSubmitted);
    on<AuthEmailUpdateSubmitted>(_onEmailUpdateSubmitted);
    on<AuthPasswordUpdateSubmitted>(_onPasswordUpdateSubmitted);
    on<AuthDisplayNameUpdateSubmitted>(_onDisplayNameUpdateSubmitted);

    _authSubscription = _repository.onAuthStateChange.listen((data) {
      AppLogger.i('AUTH', 'supabase event=${data.event} hasSession=${data.session != null}');
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

  void _onEmailChanged(AuthEmailChanged event, Emitter<AuthState> emit) {
    AppLogger.d('AUTH', 'email changed → ${AppLogger.maskEmail(event.email)}');
    emit(state.copyWith(email: event.email));
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    if (event.session != null) {
      AppLogger.i('AUTH', 'session changed → success user=${event.session!.user.email}');
      final userEntity =
          AuthUserModel.fromSupabaseUser(event.session!.user).toEntity();

      emit(
        state.copyWith(
          status: AuthStatus.success,
          loadingAction: AuthLoadingAction.none,
          session: event.session,
          user: userEntity,
        ),
      );
    } else {
      AppLogger.i('AUTH', 'session changed → signed out, reset to initial');
      emit(
        state.copyWith(
          status: AuthStatus.initial,
          loadingAction: AuthLoadingAction.none,
          session: null,
          user: null,
        ),
      );
    }
  }

  void _onEmailSubmitted(AuthEmailSubmitted event, Emitter<AuthState> emit) {
    AppLogger.i('AUTH', 'email submitted: ${AppLogger.maskEmail(state.email)}');
    final validationError = AppValidators.validateEmail(state.email);
    if (validationError != null) {
      AppLogger.w('AUTH', 'email validation failed: $validationError');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: validationError,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.emailSubmitted,
        loadingAction: AuthLoadingAction.none,
        errorMsg: null,
        message: null,
      ),
    );
  }

  Future<void> _onPasswordSubmitted(
    AuthPasswordSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.i('AUTH', 'password submitted for ${AppLogger.maskEmail(state.email)} (len=${event.password.trim().length})');
    final password = event.password.trim();
    if (password.length < 6) {
      AppLogger.w('AUTH', 'password too short');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Password must be at least 6 characters',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.password,
        errorMsg: null,
        message: null,
      ),
    );
    AppLogger.d('AUTH', 'password loading… checking internet');

    if (!await InternetUtils.isConnected()) {
      AppLogger.w('AUTH', 'password flow aborted — offline');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }

    try {
      AppLogger.i('AUTH', 'trying signInWithPassword…');
      final response = await _authUseCases.signInWithPassword(
        email: state.email.trim(),
        password: password,
      );

      if (response != null) {
        AppLogger.i('AUTH', 'signIn success user=${response.email}');
        Telemetry.track('auth_success', {
          'method': 'password',
          'email': AppLogger.maskEmail(response.email),
          'auto_signup': false,
        });
        emit(
          state.copyWith(
            status: AuthStatus.success,
            loadingAction: AuthLoadingAction.none,
            session: _repository.currentSession,
            user: response,
          ),
        );
        return;
      }
    } on supabase.AuthException catch (e) {
      AppLogger.w('AUTH', 'signIn AuthException code=${e.code} msg=${e.message}');
      final errorMsgLower = e.message.toLowerCase();
      // If error indicates user not found or invalid credentials, attempt sign up automatically
      if (errorMsgLower.contains('invalid') ||
          errorMsgLower.contains('user not found') ||
          errorMsgLower.contains('credentials') ||
          e.code == 'invalid_credentials') {
        AppLogger.i('AUTH', 'auto sign-up fallback…');
        try {
          final signUpResponse = await _authUseCases.signUpWithPassword(
            email: state.email.trim(),
            password: password,
          );

          if (signUpResponse != null) {
            AppLogger.i('AUTH', 'auto sign-up success user=${signUpResponse.email}');
            Telemetry.track('auth_success', {
              'method': 'password',
              'email': AppLogger.maskEmail(signUpResponse.email),
              'auto_signup': true,
            });
            emit(
              state.copyWith(
                status: AuthStatus.success,
                loadingAction: AuthLoadingAction.none,
                session: _repository.currentSession,
                user: signUpResponse,
              ),
            );
            return;
          } else {
            AppLogger.i('AUTH', 'sign-up null user → otpSent (confirm email)');
            emit(
              state.copyWith(
                status: AuthStatus.otpSent,
                loadingAction: AuthLoadingAction.none,
                message: 'Account created! Please check your email to confirm registration if required.',
              ),
            );
            return;
          }
        } on supabase.AuthException catch (signUpError) {
          if (signUpError.message.toLowerCase().contains(
                'already registered',
              ) ||
              signUpError.message.toLowerCase().contains('already exists')) {
            emit(
              state.copyWith(
                status: AuthStatus.failure,
                loadingAction: AuthLoadingAction.none,
                errorMsg: 'Incorrect password for this existing account.',
              ),
            );
            return;
          }
          emit(
            state.copyWith(
              status: AuthStatus.failure,
              loadingAction: AuthLoadingAction.none,
              errorMsg: friendlyAuthError(signUpError),
            ),
          );
          return;
        } catch (signUpError) {
          emit(
            state.copyWith(
              status: AuthStatus.failure,
              loadingAction: AuthLoadingAction.none,
              errorMsg: friendlyAuthError(signUpError),
            ),
          );
          return;
        }
      }

      AppLogger.e('AUTH', 'password signIn failed: ${e.message}');
      Telemetry.track('auth_failed', {
        'method': 'password',
        'email': AppLogger.maskEmail(state.email),
        'error': e.message,
      });
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
      return;
    } catch (e, st) {
      AppLogger.e('AUTH', 'password flow failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
      return;
    }
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.i('AUTH', 'OTP submitted len=${event.otp.trim().length} for ${AppLogger.maskEmail(state.email)}');
    if (event.otp.trim().isEmpty) {
      AppLogger.w('AUTH', 'OTP empty');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please enter the verification code',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.otp,
        errorMsg: null,
        message: null,
      ),
    );

    if (!await InternetUtils.isConnected()) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }

    try {
      AppLogger.d('AUTH', 'verifying OTP…');
      final response = await _authUseCases.verifyOtp(
        email: state.email.trim(),
        otp: event.otp.trim(),
      );
      if (response != null) {
        AppLogger.i('AUTH', 'OTP success user=${response.email}');
        Telemetry.track('auth_success', {
          'method': 'otp',
          'email': AppLogger.maskEmail(response.email),
        });
        emit(
          state.copyWith(
            status: AuthStatus.success,
            loadingAction: AuthLoadingAction.none,
            session: _repository.currentSession,
            user: response,
          ),
        );
      } else {
        AppLogger.w('AUTH', 'OTP verify returned null');
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg:
                'Verification failed. Please check the code and try again.',
          ),
        );
      }
    } on supabase.AuthException catch (e) {
      AppLogger.e('AUTH', 'OTP AuthException: ${e.message}');
      Telemetry.track('auth_failed', {'method': 'otp', 'error': e.message});
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'OTP failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }

  Future<void> _onGoogleSubmitted(
    AuthGoogleSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.i('AUTH', 'Google sign-in tapped');
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.google,
        errorMsg: null,
        message: null,
      ),
    );

    if (!await InternetUtils.isConnected()) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }

    try {
      AppLogger.d('AUTH', 'launching Google OAuth…');
      final launched = await _authUseCases.signInWithGoogle();
      AppLogger.i('AUTH', 'Google OAuth launched=$launched (await deep-link callback)');
      Telemetry.track('auth_google_launched', {'launched': launched});
      if (!launched) {
        AppLogger.w('AUTH', 'Google OAuth browser not launched');
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg: 'Failed to open browser for Google authentication.',
          ),
        );
      }
    } on supabase.AuthException catch (e) {
      AppLogger.e('AUTH', 'Google AuthException: ${e.message}');
      Telemetry.track('auth_failed', {'method': 'google', 'error': e.message});
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'Google sign-in failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }

  Future<void> _onEmailUpdateSubmitted(
    AuthEmailUpdateSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final email = event.email.trim();
    AppLogger.i('AUTH', 'email update → ${AppLogger.maskEmail(email)}');
    final validationError = AppValidators.validateEmail(email);
    if (validationError != null) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: validationError,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.account,
        errorMsg: null,
        message: null,
      ),
    );
    if (!await InternetUtils.isConnected()) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }
    try {
      final updated = await _authUseCases.updateEmail(email: email);
      if (updated == null) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg: 'Could not update email. Please try again.',
          ),
        );
        return;
      }
      AppLogger.i('AUTH', 'email update ok, confirmation sent');
      emit(
        state.copyWith(
          status: AuthStatus.success,
          loadingAction: AuthLoadingAction.none,
          user: updated,
          message: 'Verification link sent to ${AppLogger.maskEmail(email)}'
              ' — confirm there to complete the change.',
        ),
      );
    } on supabase.AuthException catch (e) {
      AppLogger.w('AUTH', 'email update AuthException: ${e.message}');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'email update failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }

  Future<void> _onPasswordUpdateSubmitted(
    AuthPasswordUpdateSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    AppLogger.i('AUTH', 'password update requested');
    final password = event.password.trim();
    if (password.length < 6) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Password must be at least 6 characters',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.account,
        errorMsg: null,
        message: null,
      ),
    );
    if (!await InternetUtils.isConnected()) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }
    try {
      final updated = await _authUseCases.updatePassword(password: password);
      if (updated == null) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg: 'Could not update password. Please try again.',
          ),
        );
        return;
      }
      AppLogger.i('AUTH', 'password update ok');
      emit(
        state.copyWith(
          status: AuthStatus.success,
          loadingAction: AuthLoadingAction.none,
          user: updated,
          message: 'Password updated successfully.',
        ),
      );
    } on supabase.AuthException catch (e) {
      AppLogger.w('AUTH', 'password update AuthException: ${e.message}');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'password update failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }

  Future<void> _onDisplayNameUpdateSubmitted(
    AuthDisplayNameUpdateSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final displayName = event.displayName.trim();
    AppLogger.i('AUTH', 'display name update requested');
    if (displayName.length < 2) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Name must be at least 2 characters',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.account,
        errorMsg: null,
        message: null,
      ),
    );
    if (!await InternetUtils.isConnected()) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: 'Please connect to the internet!',
        ),
      );
      return;
    }
    try {
      final updated =
          await _authUseCases.updateDisplayName(displayName: displayName);
      if (updated == null) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg: 'Could not update name. Please try again.',
          ),
        );
        return;
      }
      AppLogger.i('AUTH', 'display name update ok');
      emit(
        state.copyWith(
          status: AuthStatus.success,
          loadingAction: AuthLoadingAction.none,
          user: updated,
          message: 'Name updated successfully.',
        ),
      );
    } on supabase.AuthException catch (e) {
      AppLogger.w('AUTH', 'display name update AuthException: ${e.message}');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'display name update failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }

  Future<void> _onSignOutSubmitted(
    AuthSignOutSubmitted event,
    Emitter<AuthState> emit,
  ) async {    AppLogger.i('AUTH', 'sign-out requested');
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.none,
      ),
    );
    try {
      await _authUseCases.signOut();
      AppLogger.i('AUTH', 'sign-out done → initial');
      Telemetry.track('auth_sign_out', {});
      emit(
        const AuthState(
          status: AuthStatus.initial,
          loadingAction: AuthLoadingAction.none,
        ),
      );
    } catch (e, st) {
      AppLogger.e('AUTH', 'sign-out failed', e, st);
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: friendlyAuthError(e),
        ),
      );
    }
  }
}
