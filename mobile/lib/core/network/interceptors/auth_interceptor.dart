import 'package:dio/dio.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

/// ═══════════════════════════════════════════════════════════
/// Auth Interceptor
/// 
/// بيضيف الـ Token والـ Tenant ID لكل Request
/// وبيتعامل مع خطأ 401 (Unauthorized)
/// ═══════════════════════════════════════════════════════════
class AuthInterceptor extends Interceptor {
  
  /// ═══════════════════════════════════════════════════════
  /// قبل ما الـ Request يخرج
  /// ═══════════════════════════════════════════════════════
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // ─── 1. هات الـ Token ───
    final token = await SecureStorageService.instance.getToken();
    
    // ─── 2. هات الـ Tenant ID ───
    final tenantId = await SecureStorageService.instance.getTenantId();

    // ─── 3. ضيفهم في الـ Headers ───
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    
    if (tenantId != null && tenantId.isNotEmpty) {
      options.headers['X-Tenant-Id'] = tenantId;
    }

    // ─── 4. كمّل الـ Request ───
    handler.next(options);
  }

  /// ═══════════════════════════════════════════════════════
  /// لو حصل خطأ في الـ Response
  /// ═══════════════════════════════════════════════════════
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ─── لو التوكن انتهى (401) ───
    if (err.response?.statusCode == 401) {
      // TODO: هنا نعمل Logout أو Refresh Token
      // ممكن نستخدم EventBus أو Stream عشان نبلغ التطبيق
      // إنه لازم يرجع لشاشة Login
    }
    
    handler.next(err);
  }
}