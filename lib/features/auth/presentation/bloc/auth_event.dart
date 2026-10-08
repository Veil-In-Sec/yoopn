part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthEmailChanged extends AuthEvent {
  final String email;

  const AuthEmailChanged(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthEmailSubmitted extends AuthEvent {
  const AuthEmailSubmitted();
}

class AuthGoogleSubmitted extends AuthEvent {
  const AuthGoogleSubmitted();
}
