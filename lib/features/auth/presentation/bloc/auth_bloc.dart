import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:yoopn/core/utils/app_validators.dart';
import 'package:yoopn/core/utils/internet_connections.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthState()) {
    on<AuthEmailChanged>(_onEmailChanged);
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthGoogleSubmitted>(_onGoogleSubmitted);
  }

  void _onEmailChanged(
    AuthEmailChanged event,
    Emitter<AuthState> emit,
  ) {
    emit(state.copyWith(email: event.email));
  }

  Future<void> _onEmailSubmitted(
    AuthEmailSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final validationError = AppValidators.validateEmail(state.email);
    if (validationError != null) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: validationError,
      ));
      return;
    }

    emit(state.copyWith(status: AuthStatus.loading));

    if (!await InternetUtils.isConnected()) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please connect to the internet!',
      ));
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(status: AuthStatus.success));
  }

  Future<void> _onGoogleSubmitted(
    AuthGoogleSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    if (!await InternetUtils.isConnected()) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMsg: 'Please connect to the internet!',
      ));
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
    emit(state.copyWith(status: AuthStatus.success));
  }
}
