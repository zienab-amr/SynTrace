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
      final statusCode = response.statusCode;
      if (_isSuccessStatus(statusCode) && response.data is Map) {
        return ApiResponse.success(
          data: AuthResponse.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          ),
          statusCode: statusCode,
        );
      }
      return ApiResponse.failure(
        message: _messageFromData(
          response.data,
          fallback: statusCode == 200
              ? 'The server returned an invalid login response.'
              : 'Login failed${statusCode == null ? '' : ' (HTTP $statusCode)'}.',
        ),
        statusCode: statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _extractError(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      return ApiResponse.failure(message: 'Unexpected login error: $error');
    }
  }

  Future<ApiResponse<RegisterResponse>> signup(SignupRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.register,
        data: request.toJson(),
      );
      final statusCode = response.statusCode;
      if (_isSuccessStatus(statusCode) && response.data is Map) {
        return ApiResponse.success(
          data: RegisterResponse.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          ),
          statusCode: statusCode,
        );
      }
      return ApiResponse.failure(
        message: _messageFromData(
          response.data,
          fallback: statusCode == 200 || statusCode == 201
              ? 'The server returned an invalid registration response.'
              : 'Registration failed${statusCode == null ? '' : ' (HTTP $statusCode)'}.',
        ),
        statusCode: statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _extractError(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      return ApiResponse.failure(
        message: 'Unexpected registration error: $error',
      );
    }
  }

  Future<ApiResponse<bool>> sendOtp(
    String email, {
    OtpPurpose purpose = OtpPurpose.registration,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.sendOtp,
        data: {
          'request': {'email': email, 'purpose': purpose.name},
        },
      );
      final statusCode = response.statusCode;
      if (_isSuccessStatus(statusCode)) {
        return ApiResponse.success(data: true, statusCode: statusCode);
      }
      return ApiResponse.failure(
        message: _messageFromData(
          response.data,
          fallback:
              'Could not send the verification code${statusCode == null ? '' : ' (HTTP $statusCode)'}.',
        ),
        statusCode: statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _extractError(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      return ApiResponse.failure(message: 'Unexpected OTP error: $error');
    }
  }

  Future<ApiResponse<OtpVerificationResult>> verifyOtp({
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
      final statusCode = response.statusCode;
      final data = response.data;
      if (_isSuccessStatus(statusCode) && data is Map) {
        final result = OtpVerificationResult.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (result.verified) {
          return ApiResponse.success(data: result, statusCode: statusCode);
        }
      }
      final fallback = _isSuccessStatus(statusCode)
          ? 'The verification code is incorrect or expired.'
          : 'Could not verify the code${statusCode == null ? '' : ' (HTTP $statusCode)'}.'
                .toString();
      return ApiResponse.failure(
        message: _messageFromData(data, fallback: fallback),
        statusCode: statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _extractError(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      return ApiResponse.failure(
        message: 'Unable to verify the code. Please request a new code.',
      );
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
      if (_isSuccessStatus(response.statusCode) && response.data is Map) {
        return ApiResponse.success(
          data: Map<String, dynamic>.from(response.data as Map),
          statusCode: response.statusCode,
        );
      }
      return ApiResponse.failure(
        message: _messageFromData(
          response.data,
          fallback: 'Failed to load profile.',
        ),
        statusCode: response.statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message: _extractError(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      return ApiResponse.failure(message: 'Unexpected profile error: $error');
    }
  }

  Future<ApiResponse<bool>> resetPassword(ResetPasswordRequest request) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.resetPassword,
        data: request.toJson(),
      );
      if (_isSuccessStatus(response.statusCode)) {
        return ApiResponse.success(data: true, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        message: 'Password reset failed. Check your code and password.',
        statusCode: response.statusCode,
      );
    } on DioException catch (error) {
      return ApiResponse.failure(
        message:
            'Unable to confirm password reset. Check your connection or try signing in.',
        statusCode: error.response?.statusCode,
      );
    } catch (_) {
      return ApiResponse.failure(message: 'Unable to confirm password reset.');
    }
  }

  bool _isSuccessStatus(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  String _extractError(DioException error) {
    final responseMessage = _messageFromData(
      error.response?.data,
      fallback: '',
    );
    if (responseMessage.isNotEmpty) return responseMessage;
    if (error.error is ApiException) {
      return (error.error as ApiException).message;
    }
    final cause = error.error?.toString().trim();
    if (cause != null && cause.isNotEmpty && cause != 'null') return cause;
    final message = error.message?.trim();
    return message == null || message.isEmpty || message == 'null'
        ? 'Network request failed.'
        : message;
  }

  String _messageFromData(dynamic data, {required String fallback}) {
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }

      final errors = data['errors'];
      if (errors is Map) {
        final messages = <String>[];
        for (final entry in errors.entries) {
          final value = entry.value;
          final details = value is List
              ? value
                    .whereType<String>()
                    .where((item) => item.trim().isNotEmpty)
                    .toList()
              : value is String && value.trim().isNotEmpty
              ? [value.trim()]
              : <String>[];
          if (details.isNotEmpty) {
            messages.add('${entry.key}: ${details.join(' ')}');
          }
        }
        if (messages.isNotEmpty) return messages.join(' ');
      } else if (errors is List) {
        final messages = errors
            .whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }

      final title = data['title'];
      if (title is String && title.trim().isNotEmpty) return title.trim();
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }
}
