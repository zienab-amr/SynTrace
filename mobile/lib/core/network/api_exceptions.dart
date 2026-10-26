abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException({String? message})
      : super(message: message ?? 'No Internet Connection');
}

class TimeoutException extends ApiException {
  TimeoutException({String? message})
      : super(message: message ?? 'Request Timed Out');
}

class ServerException extends ApiException {
  ServerException({required int statusCode, String? message})
      : super(
          message: message ?? 'Something went wrong. Please try again.',
          statusCode: statusCode,
        );
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message})
      : super(
          message: message ?? 'Session expired. Please log in again.',
          statusCode: 401,
        );
}

class ForbiddenException extends ApiException {
  ForbiddenException({String? message})
      : super(
          message: message ?? 'You don\'t have access to this resource',
          statusCode: 403,
        );
}

class NotFoundException extends ApiException {
  NotFoundException({String? message})
      : super(
          message: message ?? 'Resource not found',
          statusCode: 404,
        );
}

class BadRequestException extends ApiException {
  BadRequestException({String? message})
      : super(
          message: message ?? 'Invalid request. Please check your input.',
          statusCode: 400,
        );
}

class UnknownException extends ApiException {
  UnknownException({String? message})
      : super(message: message ?? 'Something went wrong. Please try again.');
}