import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_exceptions.dart';

/// ═══════════════════════════════════════════════════════════
/// Error Interceptor
/// 
/// بيحوّل DioException لـ ApiException مفهوم
/// ═══════════════════════════════════════════════════════════
class ErrorInterceptor extends Interceptor {
  
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // ─── نحوّل الـ DioException لـ ApiException ───
    final apiException = _mapDioException(err);

    // ─── نرمي الـ ApiException بدل الـ DioException ───
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,  // ← هنا Exception بتاعنا
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════
  /// التحويل
  /// ═══════════════════════════════════════════════════════
  ApiException _mapDioException(DioException err) {
    switch (err.type) {
      // ─── 1. مشاكل الاتصال ───
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:  

        return TimeoutException();

      // ─── 2. مشكلة في الشبكة ───
      case DioExceptionType.connectionError:
        return NetworkException();

      // ─── 3. الطلب اتلغى ───
      case DioExceptionType.cancel:
        return UnknownException(message: 'Request Cancelled');

      // ─── 4. السيرفر رجّع خطأ ───
      case DioExceptionType.badResponse:
        return _handleBadResponse(err);

      // ─── 5. مشكلة تانية ───
      case DioExceptionType.unknown:
        return _handleUnknown(err);

      // ─── 6. badCertificate (مش بنستخدمه حالياً) ───
      case DioExceptionType.badCertificate:
        return UnknownException(message: 'Bad Certificate');
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// الرد اللي فيه خطأ (4xx, 5xx)
  /// ═══════════════════════════════════════════════════════
  ApiException _handleBadResponse(DioException err) {
    final statusCode = err.response?.statusCode ?? 0;
    final data = err.response?.data;

    // ─── نستخرج رسالة الخطأ من الـ Response ───
    final serverMessage = _extractMessage(data);

    switch (statusCode) {
      case 400:
        return BadRequestException(message: serverMessage);

      case 401:
        return UnauthorizedException(message: serverMessage);

      case 403:
        return ForbiddenException(message: serverMessage);

      case 404:
        return NotFoundException(message: serverMessage);

      case 422:
        return BadRequestException(
          message: serverMessage ?? 'Validation Error',
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          statusCode: statusCode,
          message: serverMessage ?? 'Server Error',
        );

      default:
        return ServerException(
          statusCode: statusCode,
          message: serverMessage ?? 'Unexpected Error ($statusCode)',
        );
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// مشكلة مش معروفة
  /// ═══════════════════════════════════════════════════════
  ApiException _handleUnknown(DioException err) {
    // ممكن تكون مشكلة في الـ SSL، أو الـ Socket، إلخ
    final errorString = err.error?.toString() ?? '';

    if (errorString.contains('SocketException')) {
      return NetworkException();
    }

    if (errorString.contains('HandshakeException')) {
      return UnknownException(message: 'SSL Error');
    }

    return UnknownException(message: err.message);
  }

  /// ═══════════════════════════════════════════════════════
  /// استخراج رسالة الخطأ من الـ Response
  /// ═══════════════════════════════════════════════════════
  String? _extractMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      // ─── الأنماط الشائعة ───
      if (data['message'] != null) return data['message'].toString();
      if (data['error'] != null) return data['error'].toString();
      if (data['detail'] != null) return data['detail'].toString();
      if (data['title'] != null) return data['title'].toString();

      // ─── ASP.NET Validation Errors ───
      if (data['errors'] != null) {
        final errors = data['errors'];
        if (errors is Map) {
          // ناخد أول رسالة من أول حقل
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
            if (value is String) {
              return value;
            }
          }
        }
        if (errors is List && errors.isNotEmpty) {
          return errors.first.toString();
        }
      }
    }

    if (data is String && data.isNotEmpty) {
      return data;
    }

    return null;
  }
}