import '../../domain/entities/auth_user_entity.dart';

class AuthUserModel extends AuthUserEntity {
  const AuthUserModel({
    required super.id,
    required super.email,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] is int
          ? json['id'] as int
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
      };

  AuthUserModel copyWith({int? id, String? email}) {
    return AuthUserModel(
      id: id ?? this.id,
      email: email ?? this.email,
    );
  }

  AuthUserEntity toEntity() => AuthUserEntity(id: id, email: email);

  factory AuthUserModel.fromEntity(AuthUserEntity entity) {
    return AuthUserModel(id: entity.id, email: entity.email);
  }
}
