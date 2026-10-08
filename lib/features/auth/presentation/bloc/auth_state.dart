part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, success, failure }

final class AuthState extends Equatable {
  final AuthStatus status;
  final String? errorMsg;
  final String email;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMsg,
    this.email = '',
  });

  AuthState copyWith({
    AuthStatus? status,
    String? errorMsg,
    String? email,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMsg: errorMsg,
      email: email ?? this.email,
    );
  }

  @override
  List<Object?> get props => [status, errorMsg, email];
}
