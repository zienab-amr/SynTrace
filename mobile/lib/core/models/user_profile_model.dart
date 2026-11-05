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
  final String? phoneNumber;
  final List<String> permissions;

  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.organizationName,
    required this.organizationId,
    this.avatarUrl,
    this.phoneNumber,
    this.permissions = const [],
  });

  factory UserProfileModel.fromUser(UserModel user) {
    return UserProfileModel(
      id: user.id,
      fullName: user.name,
      email: user.email,
      role: _capitalize(user.role.value),
      organizationName: user.companyName ?? 'Organization',
      organizationId: user.tenantId ?? '',
      avatarUrl: user.avatarUrl,
      phoneNumber: user.phoneNumber,
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  UserProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? organizationName,
    String? organizationId,
    String? avatarUrl,
    String? phoneNumber,
    List<String>? permissions,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      organizationName: organizationName ?? this.organizationName,
      organizationId: organizationId ?? this.organizationId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      permissions: permissions ?? this.permissions,
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
    phoneNumber,
    permissions,
  ];
}
