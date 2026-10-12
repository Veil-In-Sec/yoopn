class AuthUserEntity {
  const AuthUserEntity({
    required this.id,
    required this.email,
    this.photoUrl,
    this.displayName,
  });

  final int id;
  final String email;

  final String? photoUrl;

  final String? displayName;
}
