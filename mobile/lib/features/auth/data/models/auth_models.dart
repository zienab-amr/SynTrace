import 'package:equatable/equatable.dart';
import 'package:syntrace/core/models/user_model.dart';

/// ═══════════════════════════════════════════════════════════
/// Login Request
/// ═══════════════════════════════════════════════════════════
class LoginRequest extends Equatable {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  @override
  List<Object?> get props => [email, password];
}

/// ═══════════════════════════════════════════════════════════
/// Signup Request
/// ═══════════════════════════════════════════════════════════
class SignupRequest extends Equatable {
  final String fullName;
  final String email;
  final String password;

  const SignupRequest({
    required this.fullName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'password': password,
      };

  @override
  List<Object?> get props => [fullName, email, password];
}

/// ═══════════════════════════════════════════════════════════
/// Auth Response
/// ═══════════════════════════════════════════════════════════
class AuthResponse extends Equatable {
  final String token;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      user: UserModel.fromJson(
        json['user'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'refreshToken': refreshToken,
        'user': user.toJson(),
      };

  @override
  List<Object?> get props => [token, refreshToken, user];
}