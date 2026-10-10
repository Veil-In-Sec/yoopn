class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    required this.email,
    this.photoUrl,
    this.displayName,
  });

  final int id;
  final String email;

  /// OAuth avatar (Google `avatar_url`), null for email/password accounts.
  final String? photoUrl;

  /// Profile display name (OAuth `full_name` or user-set).
  final String? displayName;
}
