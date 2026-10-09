import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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

    _authSubscription = _repository.onAuthStateChange.listen((data) {
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
    emit(state.copyWith(email: event.email));
  }

  void _onSessionChanged(AuthSessionChanged event, Emitter<AuthState> emit) {
    if (event.session != null) {
      final supabaseUser = event.session!.user;
      final userEntity = AuthUserModel(
        id: supabaseUser.id.hashCode,
        email: supabaseUser.email ?? '',
      ).toEntity();

      emit(
        state.copyWith(
          status: AuthStatus.success,
          loadingAction: AuthLoadingAction.none,
          session: event.session,
          user: userEntity,
        ),
      );
    } else {
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
    final validationError = AppValidators.validateEmail(state.email);
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
        loadingAction: AuthLoadingAction.password,
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
      final response = await _authUseCases.signInWithPassword(
        email: state.email.trim(),
        password: password,
      );

      if (response != null) {
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
      final errorMsgLower = e.message.toLowerCase();
      // If error indicates user not found or invalid credentials, attempt sign up automatically
      if (errorMsgLower.contains('invalid') ||
          errorMsgLower.contains('user not found') ||
          errorMsgLower.contains('credentials') ||
          e.code == 'invalid_credentials') {
        try {
          final signUpResponse = await _authUseCases.signUpWithPassword(
            email: state.email.trim(),
            password: password,
          );

          if (signUpResponse != null) {
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
              errorMsg: signUpError.message,
            ),
          );
          return;
        } catch (signUpError) {
          emit(
            state.copyWith(
              status: AuthStatus.failure,
              loadingAction: AuthLoadingAction.none,
              errorMsg: signUpError.toString(),
            ),
          );
          return;
        }
      }

      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.message,
        ),
      );
      return;
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.toString(),
        ),
      );
      return;
    }
  }

  Future<void> _onOtpSubmitted(
    AuthOtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (event.otp.trim().isEmpty) {
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
      final response = await _authUseCases.verifyOtp(
        email: state.email.trim(),
        otp: event.otp.trim(),
      );
      if (response != null) {
        emit(
          state.copyWith(
            status: AuthStatus.success,
            loadingAction: AuthLoadingAction.none,
            session: _repository.currentSession,
            user: response,
          ),
        );
      } else {
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
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.toString(),
        ),
      );
    }
  }

  Future<void> _onGoogleSubmitted(
    AuthGoogleSubmitted event,
    Emitter<AuthState> emit,
  ) async {
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
      final launched = await _authUseCases.signInWithGoogle();
      if (!launched) {
        emit(
          state.copyWith(
            status: AuthStatus.failure,
            loadingAction: AuthLoadingAction.none,
            errorMsg: 'Failed to open browser for Google authentication.',
          ),
        );
      }
    } on supabase.AuthException catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSignOutSubmitted(
    AuthSignOutSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuthStatus.loading,
        loadingAction: AuthLoadingAction.none,
      ),
    );
    try {
      await _authUseCases.signOut();
      emit(
        const AuthState(
          status: AuthStatus.initial,
          loadingAction: AuthLoadingAction.none,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          loadingAction: AuthLoadingAction.none,
          errorMsg: e.toString(),
        ),
      );
    }
  }
}
