import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_client.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_exceptions.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

class AuthRepository {
  Future<ApiResponse<AuthResponse>> login(LoginRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return ApiResponse.success(
          data: AuthResponse.fromJson(response.data as Map<String, dynamic>),
        );
      } else {
        return ApiResponse.failure(
          message: response.data['message']?.toString() ?? 'Login failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  Future<ApiResponse<RegisterResponse>> signup(SignupRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        data: request.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(
          data: RegisterResponse.fromJson(
            response.data as Map<String, dynamic>,
          ),
        );
      } else {
        return ApiResponse.failure(
          message:
              response.data['message']?.toString() ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  Future<ApiResponse<bool>> sendOtp(String email) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.sendOtp,
        data: {
          'request': {'email': email},
        },
      );
      return ApiResponse.success(data: response.statusCode == 200);
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  Future<ApiResponse<bool>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.verifyOtp,
        data: {
          'request': {'email': email, 'otp': otp},
        },
      );
      return ApiResponse.success(data: response.statusCode == 200);
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

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

  Future<ApiResponse<Map<String, dynamic>>> getEmployeeProfile(
    String employeeId,
  ) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.employeeById,
        queryParameters: {'EmployeeId': employeeId},
      );

      if (response.statusCode == 200 && response.data is Map) {
        return ApiResponse.success(data: response.data as Map<String, dynamic>);
      }
      return ApiResponse.failure(message: 'Failed to load profile');
    } on DioException catch (e) {
      return ApiResponse.failure(message: _extractError(e));
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }

  String _extractError(DioException e) {
    final apiException = e.error is ApiException
        ? e.error as ApiException
        : UnknownException(message: e.message);
    return apiException.message;
  }
}
