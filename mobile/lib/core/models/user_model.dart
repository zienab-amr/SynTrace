import 'package:equatable/equatable.dart';

/// ═══════════════════════════════════════════════════════════
/// User Model
/// 
/// بيمثل المستخدم في النظام
/// ═══════════════════════════════════════════════════════════
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final UserRole role;
  final String? tenantId;   
  final String? companyName;      // ← للـ Multi-Tenancy
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.tenantId,
    this.companyName,
    this.createdAt,
    this.updatedAt,
  });

  /// ═══════════════════════════════════════════════════════
  /// من JSON
  /// ═══════════════════════════════════════════════════════
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      tenantId: json['tenantId'] as String?,
      companyName: json['companyName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  /// ═══════════════════════════════════════════════════════
  /// إلى JSON
  /// ═══════════════════════════════════════════════════════
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role.value,
      'tenantId': tenantId,
      'companyName': companyName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// ═══════════════════════════════════════════════════════
  /// copyWith — لتعديل نسخة من الـ Object
  /// ═══════════════════════════════════════════════════════
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    UserRole? role,
    String? tenantId,
    String? companyName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      tenantId: tenantId ?? this.tenantId,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// ═══════════════════════════════════════════════════════
  /// Helpers
  /// ═══════════════════════════════════════════════════════
  bool get isAdmin => role == UserRole.admin;
  bool get isManager => role == UserRole.manager;
  bool get isDeveloper => role == UserRole.developer;

  /// أول حرف من الاسم (للـ Avatar)
  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  /// ═══════════════════════════════════════════════════════
  /// Equatable
  /// ═══════════════════════════════════════════════════════
  @override
  List<Object?> get props => [
        id,
        name,
        email,
        avatarUrl,
        role,
        tenantId,
        companyName,
        createdAt,
        updatedAt,
      ];
}

/// ═══════════════════════════════════════════════════════════
/// User Role Enum
/// ═══════════════════════════════════════════════════════════
enum UserRole {
  admin('admin'),
  manager('manager'),
  developer('developer'),
  viewer('viewer');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? value) {
    if (value == null) return UserRole.viewer;
    return UserRole.values.firstWhere(
      (role) => role.value.toLowerCase() == value.toLowerCase(),
      orElse: () => UserRole.viewer,
    );
  }
}