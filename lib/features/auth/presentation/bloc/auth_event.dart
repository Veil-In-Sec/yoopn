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

class AuthPasswordSubmitted extends AuthEvent {
  final String password;

  const AuthPasswordSubmitted(this.password);

  @override
  List<Object?> get props => [password];
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;

  const AuthOtpSubmitted(this.otp);

  @override
  List<Object?> get props => [otp];
}

class AuthGoogleSubmitted extends AuthEvent {
  const AuthGoogleSubmitted();
}

class AuthSessionChanged extends AuthEvent {
  final supabase.Session? session;

  const AuthSessionChanged(this.session);

  @override
  List<Object?> get props => [session];
}

class AuthSignOutSubmitted extends AuthEvent {
  const AuthSignOutSubmitted();
}
