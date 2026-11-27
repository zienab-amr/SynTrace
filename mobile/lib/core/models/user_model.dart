import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserRole role;
  final List<String> roleNames;
  final String? tenantId;
  final String? companyName;
  final String? phoneNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.roleNames = const [],
    this.tenantId,
    this.companyName,
    this.phoneNumber,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roles = UserRole.readNames([json['roleNames']]);
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: roles.isEmpty
          ? UserRole.fromString(json['role'] as String?)
          : UserRole.fromNames(roles),
      roleNames: roles,
      tenantId: json['tenantId'] as String?,
      companyName: json['companyName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'roleNames': roleNames,
      'tenantId': tenantId,
      'companyName': companyName,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    UserRole? role,
    List<String>? roleNames,
    String? tenantId,
    String? companyName,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: roleNames != null
          ? UserRole.fromNames(roleNames)
          : role ?? this.role,
      roleNames: roleNames != null
          ? List.unmodifiable(roleNames)
          : (role != null && role != this.role ? const [] : this.roleNames),
      tenantId: tenantId ?? this.tenantId,
      companyName: companyName ?? this.companyName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isDeveloper => role == UserRole.developer;

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    avatarUrl,
    role,
    roleNames,
    tenantId,
    companyName,
    phoneNumber,
    createdAt,
    updatedAt,
  ];
}

enum UserRole {
  admin('admin'),
  manager('manager'),
  developer('developer'),
  viewer('viewer');

  final String value;
  const UserRole(this.value);

  static List<String> readNames(Iterable<dynamic> claims) {
    final names = <String>{};
    for (final claim in claims) {
      final values = claim is List ? claim : [claim];
      for (final value in values) {
        if (value is String && value.trim().isNotEmpty) names.add(value.trim());
      }
    }
    return List.unmodifiable(names.toList()..sort());
  }

  static UserRole fromNames(List<String> names) {
    final normalized = names.map((name) => name.toLowerCase()).toSet();
    return values.firstWhere(
      (role) => normalized.contains(role.value),
      orElse: () => viewer,
    );
  }

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.viewer;
    return UserRole.values.firstWhere(
      (role) => role.value.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.viewer,
    );
  }
}
