import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_exceptions.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

class AuthRepository {
  // ═══════════════════════════════════════════════════════
  // Send OTP
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<bool>> sendOtp(String email) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.sendOtp,
        data: {
          'request': {'email': email},
        },
      );

      if (_isSuccess(response.statusCode)) {
        return ApiResponse.success(data: true, message: 'OTP sent to $email');
      }

      return ApiResponse.failure(
        message: 'Failed to send OTP (${response.statusCode})',
      );
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Verify OTP
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<bool>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.verifyOtp,
        data: {
          'request': {
            'email': email,
            'otp': otp,
          },
        },
      );

      if (_isSuccess(response.statusCode)) {
        final isValid = response.data is bool ? response.data as bool : false;

        if (!isValid) {
          return ApiResponse.failure(message: 'Invalid or expired OTP');
        }
        return ApiResponse.success(data: true);
      }

      return ApiResponse.failure(
        message: 'Failed to verify OTP (${response.statusCode})',
      );
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Register
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<RegisterResponse>> signup(SignupRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        data: request.toJson(),
      );

      if (_isSuccess(response.statusCode)) {
        return ApiResponse.success(
          data: RegisterResponse.fromJson(
            response.data as Map<String, dynamic>,
          ),
        );
      }

      return ApiResponse.failure(
        message: 'Registration failed (${response.statusCode})',
      );
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Login
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        data: request.toJson(),
      );

      if (_isSuccess(response.statusCode)) {
        return ApiResponse.success(
          data: AuthResponse.fromJson(
            response.data as Map<String, dynamic>,
          ),
        );
      }

      return ApiResponse.failure(
        message: 'Login failed (${response.statusCode})',
      );
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Logout
  // ═══════════════════════════════════════════════════════
  Future<void> logout(String refreshToken) async {
    try {
      await ApiClient.instance.post(
        ApiEndpoints.logout,
        data: {
          'request': {'refreshToken': refreshToken},
        },
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════
  bool _isSuccess(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  String _extractError(DioException e) {
  final apiException = e.error is ApiException
      ? e.error as ApiException
      : UnknownException(message: e.message);
  return apiException.message;
}
    // ═══════════════════════════════════════════════════════
  // check Email Existance
  // ═══════════════════════════════════════════════════════
Future<bool> checkEmailExists(String email) async {
  try {
    final response = await ApiClient.instance.get(
      ApiEndpoints.checkEmail,
      queryParameters: {'email': email},
    );

    if (response.statusCode == 200 && response.data is Map) {
      return response.data['exists'] as bool? ?? false;
    }
    return false;
  } catch (_) {
    return false;
  }
}
}

