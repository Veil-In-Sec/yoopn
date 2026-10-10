part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, emailSubmitted, otpSent, success, failure }

enum AuthLoadingAction { none, email, google, password, otp, account }

final class AuthState extends Equatable {
  final AuthStatus status;
  final AuthLoadingAction loadingAction;
  final String? errorMsg;
  final String? message;
  final String email;
  final supabase.Session? session;
  final AuthUserEntity? user;

  const AuthState({
    this.status = AuthStatus.initial,
    this.loadingAction = AuthLoadingAction.none,
    this.errorMsg,
    this.message,
    this.email = '',
    this.session,
    this.user,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthLoadingAction? loadingAction,
    String? errorMsg,
    String? message,
    String? email,
    supabase.Session? session,
    AuthUserEntity? user,
  }) {
    return AuthState(
      status: status ?? this.status,
      loadingAction: loadingAction ?? this.loadingAction,
      errorMsg: errorMsg,
      message: message,
      email: email ?? this.email,
      session: session ?? this.session,
      user: user ?? this.user,
    );
  }

  @override
  List<Object?> get props =>
      [status, loadingAction, errorMsg, message, email, session, user];
}
