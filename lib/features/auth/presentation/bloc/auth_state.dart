part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, emailSubmitted, otpSent, success, failure }

enum AuthLoadingAction { none, email, google, password, otp }

final class AuthState extends Equatable {
  final AuthStatus status;
  final AuthLoadingAction loadingAction;
  final String? errorMsg;
  final String? message;
  final String email;
  final supabase.Session? session;

  const AuthState({
    this.status = AuthStatus.initial,
    this.loadingAction = AuthLoadingAction.none,
    this.errorMsg,
    this.message,
    this.email = '',
    this.session,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthLoadingAction? loadingAction,
    String? errorMsg,
    String? message,
    String? email,
    supabase.Session? session,
  }) {
    return AuthState(
      status: status ?? this.status,
      loadingAction: loadingAction ?? this.loadingAction,
      errorMsg: errorMsg,
      message: message,
      email: email ?? this.email,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props =>
      [status, loadingAction, errorMsg, message, email, session];
}
