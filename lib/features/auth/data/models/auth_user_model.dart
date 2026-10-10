import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel extends AuthUserEntity {
  const AuthUserModel({
    required super.id,
    required super.email,
    super.photoUrl,
    super.displayName,
  });

  /// Builds from a Supabase user, picking up the OAuth avatar and display
  /// name when present (Google provides `avatar_url` + `full_name`; some
  /// providers use `picture` / `display_name` / `name`).
  factory AuthUserModel.fromSupabaseUser(supabase.User user) {
    final meta = user.userMetadata;
    var photoUrl = meta?['avatar_url']?.toString();
    photoUrl ??= meta?['picture']?.toString();
    if (photoUrl != null && photoUrl.isEmpty) photoUrl = null;
    var displayName = meta?['full_name']?.toString();
    displayName ??= meta?['display_name']?.toString();
    displayName ??= meta?['name']?.toString();
    if (displayName != null && displayName.isEmpty) displayName = null;
    return AuthUserModel(
      id: user.id.hashCode,
      email: user.email ?? '',
      photoUrl: photoUrl,
      displayName: displayName,
    );
  }

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      displayName: json['displayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'photoUrl': photoUrl,
        'displayName': displayName,
      };

  AuthUserModel copyWith(
      {int? id, String? email, String? photoUrl, String? displayName}) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      displayName: displayName ?? this.displayName,
    );
  }

  AuthUserEntity toEntity() => AuthUserEntity(
        id: id,
        email: email,
        photoUrl: photoUrl,
        displayName: displayName,
      );

  factory AuthUserModel.fromEntity(AuthUserEntity entity) {
    return AuthUserModel(
      id: entity.id,
      email: entity.email,
      photoUrl: entity.photoUrl,
      displayName: entity.displayName,
    );
  }
}
