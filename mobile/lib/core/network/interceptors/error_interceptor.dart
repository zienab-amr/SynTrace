import 'package:dio/dio.dart';
import 'package:syntrace/core/network/api_exceptions.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final apiException = _mapDioException(err);

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
      ),
    );
  }

  ApiException _mapDioException(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException();

      case DioExceptionType.connectionError:
        return NetworkException();

      case DioExceptionType.cancel:
        return UnknownException(message: 'Request Cancelled');

      case DioExceptionType.badResponse:
        return _handleBadResponse(err);

      case DioExceptionType.unknown:
        return _handleUnknown(err);

      case DioExceptionType.badCertificate:
        return UnknownException(message: 'Bad Certificate');
    }
  }

  ApiException _handleBadResponse(DioException err) {
    final statusCode = err.response?.statusCode ?? 0;
    final data = err.response?.data;
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

  ApiException _handleUnknown(DioException err) {
    final errorString = err.error?.toString() ?? '';

    if (errorString.contains('SocketException')) {
      return NetworkException();
    }

    if (errorString.contains('HandshakeException')) {
      return UnknownException(message: 'SSL Error');
    }

    return UnknownException(message: 'Connection failed');
  }

  String? _extractMessage(dynamic data) {
    if (data == null) return null;

    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return _clean(data['message'].toString());
      }
      if (data['error'] != null) {
        return _clean(data['error'].toString());
      }
      if (data['detail'] != null) {
        return _clean(data['detail'].toString());
      }
      if (data['title'] != null) {
        return _clean(data['title'].toString());
      }

      if (data['errors'] != null) {
        final errors = data['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return _clean(value.first.toString());
            }
            if (value is String) {
              return _clean(value);
            }
          }
        }
        if (errors is List && errors.isNotEmpty) {
          return _clean(errors.first.toString());
        }
      }
    }

    if (data is String && data.isNotEmpty) {
      return _clean(data);
    }

    return null;
  }

  String? _clean(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.length < 150 &&
        !_looksLikeStackTrace(trimmed) &&
        !_looksLikeFilePath(trimmed)) {
      return _cleanPrefix(trimmed);
    }

    final meaningful = _findMeaningfulMessage(trimmed);
    if (meaningful != null) return meaningful;

    return null;
  }

  String _cleanPrefix(String message) {
    final cleaned = message
        .replaceFirst(RegExp(r'^System\.\w+Exception:\s*'), '')
        .replaceFirst(RegExp(r'^\w+Exception:\s*'), '')
        .trim();

    if (cleaned.isEmpty) return message;
    return cleaned;
  }

  bool _looksLikeStackTrace(String text) {
    return text.contains(' at ') &&
        (text.contains(' in ') || text.contains('line '));
  }

  bool _looksLikeFilePath(String text) {
    return text.contains('.cs:line') ||
        text.contains('.dart:') ||
        RegExp(r'[A-Za-z]:\\').hasMatch(text);
  }

  String? _findMeaningfulMessage(String text) {
    final lower = text.toLowerCase();

    if (lower.contains('already exists') ||
        lower.contains('already registered')) {
      return 'This email is already registered';
    }

    if (lower.contains('employee not found') ||
        lower.contains('user not found') ||
        lower.contains('account not found')) {
      return 'Account not found';
    }

    if (lower.contains('invalid password') ||
        lower.contains('wrong password')) {
      return 'Invalid email or password';
    }

    if (lower.contains('invalid otp') ||
        lower.contains('otp is invalid')) {
      return 'Invalid or expired OTP';
    }

    if (lower.contains('unauthorized')) {
      return 'Session expired. Please log in again.';
    }

    if (lower.contains('email must be verified')) {
      return 'Please verify your email first';
    }

    final lines = text.split('\n');
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      if (_looksLikeStackTrace(trimmedLine)) continue;
      if (_looksLikeFilePath(trimmedLine)) continue;

      if (trimmedLine.contains('Exception:')) {
        return _cleanPrefix(trimmedLine);
      }

      if (trimmedLine.length > 3 &&
          trimmedLine.length < 200 &&
          !trimmedLine.startsWith('at ')) {
        return _cleanPrefix(trimmedLine);
      }
    }

    return null;
  }
}