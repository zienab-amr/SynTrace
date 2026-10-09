import 'package:equatable/equatable.dart';
import 'package:syntrace/core/models/user_model.dart';

class UserProfileModel extends Equatable
{
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String organizationName;
  final String organizationId;
  final String? avatarUrl;
  final List<String> permissions;

  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.organizationName,
    required this.organizationId,
    this.avatarUrl,
    this.permissions = const [],
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json)
  {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'Employee',
      organizationName: json['organizationName'] as String? ?? '',
      organizationId: json['organizationId'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      permissions: (json['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  factory UserProfileModel.fromUser(UserModel user, {String? companyName})
  {
    return UserProfileModel(
      id: user.id,
      fullName: user.name,
      email: user.email,
      role: user.role.value,
      organizationName: companyName ?? 'Organization',
      organizationId: user.tenantId ?? '',
      avatarUrl: user.avatarUrl,
      permissions: const [
        'Projects',
        'Reports',
        'Knowledge Graph',
        'AI Assistant',
        'Security Center',
      ],
    );
  }

  UserProfileModel copyWith({
    String? fullName,
    String? email,
    String? role,
    String? organizationName,
    String? avatarUrl,
  }) {
    return UserProfileModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationName: organizationName ?? this.organizationName,
      organizationId: organizationId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      permissions: permissions,
    );
  }

  @override
  List<Object?> get props =>
  [
        id,
        fullName,
        email,
        role,
        organizationName,
        organizationId,
        avatarUrl,
        permissions,
      ];
}