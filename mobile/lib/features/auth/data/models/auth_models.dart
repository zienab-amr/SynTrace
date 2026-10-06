import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:syntrace/core/models/user_model.dart';

// ═══════════════════════════════════════════════════════════
// Login Request
// ═══════════════════════════════════════════════════════════
class LoginRequest extends Equatable {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'request': {
          'email': email,
          'password': password,
        },
      };

  @override
  List<Object?> get props => [email, password];
}

// ═══════════════════════════════════════════════════════════
// Signup Request
// ═══════════════════════════════════════════════════════════
class SignupRequest extends Equatable {
  final String companyName;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String password;

  const SignupRequest({
    required this.companyName,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'request': {
          'companyName': companyName,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phoneNumber': phoneNumber,
          'password': password,
        },
      };

  @override
  List<Object?> get props => [
        companyName,
        firstName,
        lastName,
        email,
        phoneNumber,
        password,
      ];
}

// ═══════════════════════════════════════════════════════════
// Auth Response
// ═══════════════════════════════════════════════════════════
class AuthResponse extends Equatable {
  final String accessToken;
  final DateTime? accessTokenExpiration;
  final String refreshToken;
  final DateTime? refreshTokenExpiration;

  const AuthResponse({
    required this.accessToken,
    this.accessTokenExpiration,
    required this.refreshToken,
    this.refreshTokenExpiration,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String? ?? '',
      accessTokenExpiration: json['accessTokenExpiration'] != null
          ? DateTime.tryParse(json['accessTokenExpiration'] as String)
          : null,
      refreshToken: json['refreshToken'] as String? ?? '',
      refreshTokenExpiration: json['refreshTokenExpiration'] != null
          ? DateTime.tryParse(json['refreshTokenExpiration'] as String)
          : null,
    );
  }

  /// ─── استخراج بيانات المستخدم من الـ JWT ───
  UserModel? extractUser() {
    try {
      final parts = accessToken.split('.');
      if (parts.length != 3) return null;

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload) as Map<String, dynamic>;

      final userId = claims[
              'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
          as String? ?? claims['sub'] as String? ?? '';
      final companyId = claims['CompanyId'] as String? ?? '';
      final role = claims[
              'http://schemas.microsoft.com/ws/2008/06/identity/claims/role']
          as String? ?? claims['role'] as String? ?? 'Admin';
      final email = claims[
              'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress']
          as String? ?? claims['email'] as String? ?? '';

      return UserModel(
        id: userId,
        name: email.isNotEmpty ? email.split('@').first : 'User',
        email: email,
        role: UserRole.fromString(role),
        tenantId: companyId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
        accessToken,
        accessTokenExpiration,
        refreshToken,
        refreshTokenExpiration,
      ];
}

// ═══════════════════════════════════════════════════════════
// Register Response
// ═══════════════════════════════════════════════════════════
class RegisterResponse extends Equatable {
  final String employeeId;
  final String companyId;
  final String email;

  const RegisterResponse({
    required this.employeeId,
    required this.companyId,
    required this.email,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      employeeId: json['employeeId'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [employeeId, companyId, email];
}