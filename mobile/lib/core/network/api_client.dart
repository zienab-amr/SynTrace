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
/// 
/// نقطة الاتصال الوحيدة بالسيرفر
/// بيجمع Dio + كل الـ Interceptors
/// ═══════════════════════════════════════════════════════════
class ApiClient {
  // ─── Singleton ───
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // ─── Dio ───
  late final Dio _dio;
  Dio get dio => _dio;

  // ─── هل تم التهيئة؟ ───
  bool _isInitialized = false;

  // ═══════════════════════════════════════════════════════
  // init()
  // 
  // لازم تتنادى مرة واحدة في main.dart
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
          'Accept': 'application/json',
        },
        // ─── نتعامل مع كل الأخطاء بنفسنا ───
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );

    // ═══════════════════════════════════════════════════
    // ترتيب الـ Interceptors مهم جداً!
    // ═══════════════════════════════════════════════════
    _dio.interceptors.addAll([
      AuthInterceptor(),                    // 1. يضيف Token
      LoggerInterceptor(),                  // 2. يطبع (Debug فقط)
      ErrorInterceptor(),                   // 3. يحول الأخطاء
      RetryInterceptor(dio: _dio),          // 4. يعيد المحاولة
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
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
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
  // 
  // Helper ذكي: بيرجع ApiResponse<T> مباشرة
  // بيتعامل مع كل الأخطاء تلقائياً
  // ═══════════════════════════════════════════════════════
  Future<ApiResponse<T>> safeRequest<T>({
    required Future<Response> Function() request,
    required T Function(dynamic data) fromData,
  }) async {
    try {
      final response = await request();
      
      // ─── نجح؟ ───
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ApiResponse<T>.fromJson(
          response.data as Map<String, dynamic>,
          fromData: fromData,
          statusCode: response.statusCode,
        );
      }

      // ─── رجع Status Code غريب ───
      return ApiResponse.failure(
        message: 'Unexpected status: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      // ─── استخرج ApiException من جوه DioException ───
      final apiException = e.error is ApiException
          ? e.error as ApiException
          : UnknownException(message: e.message);

      return ApiResponse.failure(
        message: apiException.message,
        statusCode: apiException.statusCode,
      );
    } catch (e) {

      return ApiResponse.failure(
        message: 'Unexpected error: $e',
      );
    }
  }
}