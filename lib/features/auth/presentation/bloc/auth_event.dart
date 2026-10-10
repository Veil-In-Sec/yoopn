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

  @override
  String toString() => 'AuthEmailChanged(${AppLogger.maskEmail(email)})';
}

class AuthEmailSubmitted extends AuthEvent {
  const AuthEmailSubmitted();
}

class AuthPasswordSubmitted extends AuthEvent {
  final String password;

  const AuthPasswordSubmitted(this.password);

  @override
  List<Object?> get props => [password];

  // Never log credentials: Equatable's default toString prints every prop.
  @override
  String toString() => 'AuthPasswordSubmitted(***)';
}

class AuthOtpSubmitted extends AuthEvent {
  final String otp;

  const AuthOtpSubmitted(this.otp);

  @override
  List<Object?> get props => [otp];

  // Never log credentials: Equatable's default toString prints every prop.
  @override
  String toString() => 'AuthOtpSubmitted(***)';
}

class AuthGoogleSubmitted extends AuthEvent {
  const AuthGoogleSubmitted();
}

class AuthSessionChanged extends AuthEvent {
  final supabase.Session? session;

  const AuthSessionChanged(this.session);

  @override
  List<Object?> get props => [session];

  // Never log tokens: the session stringifies access/refresh tokens.
  @override
  String toString() =>
      'AuthSessionChanged(hasSession=${session != null})';
}

class AuthSignOutSubmitted extends AuthEvent {
  const AuthSignOutSubmitted();
}

class AuthEmailUpdateSubmitted extends AuthEvent {
  final String email;

  const AuthEmailUpdateSubmitted(this.email);

  @override
  List<Object?> get props => [email];

  @override
  String toString() =>
      'AuthEmailUpdateSubmitted(${AppLogger.maskEmail(email)})';
}

class AuthPasswordUpdateSubmitted extends AuthEvent {
  final String password;

  const AuthPasswordUpdateSubmitted(this.password);

  @override
  List<Object?> get props => [password];

  // Never log credentials: Equatable's default toString prints every prop.
  @override
  String toString() => 'AuthPasswordUpdateSubmitted(***)';
}

class AuthDisplayNameUpdateSubmitted extends AuthEvent {
  final String displayName;

  const AuthDisplayNameUpdateSubmitted(this.displayName);

  @override
  List<Object?> get props => [displayName];
}
