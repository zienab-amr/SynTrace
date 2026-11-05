import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/api_exceptions.dart';
import 'package:syntrace/core/network/api_response.dart';
import 'package:syntrace/core/network/interceptors/auth_interceptor.dart';
import 'package:syntrace/core/network/interceptors/error_interceptor.dart';
import 'package:syntrace/core/network/interceptors/logger_interceptor.dart';
import 'package:syntrace/core/network/interceptors/retry_interceptor.dart';

/// ═══════════════════════════════════════════════════════════
/// ApiClient
/// ═══════════════════════════════════════════════════════════
class ApiClient {
  // ─── Singleton ───
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // ─── Dio ───
  late final Dio _dio;
  Dio get dio => _dio;

  bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════
  // init()
  // ═══════════════════════════════════════════════════════
  void init() {
    if (_isInitialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );
    _dio.interceptors.addAll([
      AuthInterceptor(),
      LoggerInterceptor(),
      ErrorInterceptor(),
      RetryInterceptor(dio: _dio),
    ]);

    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('✅ ApiClient initialized');
      debugPrint('   Base URL: ${ApiEndpoints.baseUrl}');
    }
  }

  // ═══════════════════════════════════════════════════════
  // Helper: GET
  // ═══════════════════════════════════════════════════════
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  // ═══════════════════════════════════════════════════════
  // Helper: POST
  // ═══════════════════════════════════════════════════════
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ═══════════════════════════════════════════════════════
  // Helper: PUT
  // ═══════════════════════════════════════════════════════
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ═══════════════════════════════════════════════════════
  // Helper: PATCH
  // ═══════════════════════════════════════════════════════
  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ═══════════════════════════════════════════════════════
  // Helper: DELETE
  // ═══════════════════════════════════════════════════════
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // ═══════════════════════════════════════════════════════
  // safeRequest<T>
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<T>> safeRequest<T>({
    required Future<Response> Function() request,
    required T Function(dynamic data) fromData,
  }) async {
    try {
      final response = await request();

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromData: fromData,
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.failure(
        message: 'Unexpected status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final apiException = e.error is ApiException
          ? e.error as ApiException
          : UnknownException(message: e.message);

      return ApiResponse.failure(
        message: apiException.message,
        statusCode: apiException.statusCode,
      );
    } catch (e) {
      return ApiResponse.failure(message: 'Unexpected error: $e');
    }
  }
}
