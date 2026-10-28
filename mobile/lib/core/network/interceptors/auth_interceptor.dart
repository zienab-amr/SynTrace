import 'package:dio/dio.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

/// ═══════════════════════════════════════════════════════════
/// Auth Interceptor
/// ═══════════════════════════════════════════════════════════
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorageService.instance.getToken();
    
    final tenantId = await SecureStorageService.instance.getTenantId();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    if (tenantId != null && tenantId.isNotEmpty) {
      options.headers['X-Tenant-Id'] = tenantId;
    }

    handler.next(options);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
    }
    
    handler.next(err);
  }
}