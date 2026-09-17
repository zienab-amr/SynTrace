/// ═══════════════════════════════════════════════════════════
/// الـ Base Class لكل الأخطاء
/// ═══════════════════════════════════════════════════════════
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

/// ═══════════════════════════════════════════════════════════
/// 1. مشكلة في النت
/// ═══════════════════════════════════════════════════════════
class NetworkException extends ApiException {
  NetworkException()
      : super(
          message: 'No Internet Connection',
        );
}

/// ═══════════════════════════════════════════════════════════
/// 2. السيرفر اتأخر في الرد
/// ═══════════════════════════════════════════════════════════
class TimeoutException extends ApiException {
  TimeoutException()
      : super(
          message: 'Request Timeout',
        );
}

/// ═══════════════════════════════════════════════════════════
/// 3. مشكلة في السيرفر (500, 502, 503)
/// ═══════════════════════════════════════════════════════════
class ServerException extends ApiException {
  ServerException({required int statusCode, String? message})
      : super(
          message: message ?? 'Server Error',
          statusCode: statusCode,
        );
}

/// ═══════════════════════════════════════════════════════════
/// 4. التوكن انتهى أو مش موجود (401)
/// ═══════════════════════════════════════════════════════════
class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message})
      : super(
          message: message ?? 'Unauthorized',
          statusCode: 401,
        );
}

/// ═══════════════════════════════════════════════════════════
/// 5. مفيش صلاحية للوصول (403)
/// ═══════════════════════════════════════════════════════════
class ForbiddenException extends ApiException {
  ForbiddenException({String? message})
      : super(
          message: message ?? 'Access Forbidden',
          statusCode: 403,
        );
}

/// ═══════════════════════════════════════════════════════════
/// 6. مش لاقي حاجة (404)
/// ═══════════════════════════════════════════════════════════
class NotFoundException extends ApiException {
  NotFoundException({String? message})
      : super(
          message: message ?? 'Resource Not Found',
          statusCode: 404,
        );
}

/// ═══════════════════════════════════════════════════════════
/// 7. البيانات اللي بعتيها غلط (400, 422)
/// ═══════════════════════════════════════════════════════════
class BadRequestException extends ApiException {
  BadRequestException({String? message})
      : super(
          message: message ?? 'Bad Request',
          statusCode: 400,
        );
}

/// ═══════════════════════════════════════════════════════════
/// 8. مشكلة مش معروفة
/// ═══════════════════════════════════════════════════════════
class UnknownException extends ApiException {
  UnknownException({String? message})
      : super(
          message: message ?? 'Unknown Error Occurred',
        );
}