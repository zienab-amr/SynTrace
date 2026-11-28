import 'package:dio/dio.dart';

Uri? readIntegrationUrl(dynamic data) {
  final dynamic value;

  if (data is String) {
    value = data;
  } else if (data is Map) {
    value = data['url'] ?? data['authorizeUrl'] ?? data['authUrl'];
  } else {
    return null;
  }

  if (value is! String) return null;

  final uri = Uri.tryParse(value.trim());

  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }

  return uri;
}

void ensureIntegrationSuccess(Response response) {
  final code = response.statusCode;

  if (code == null || code < 200 || code >= 300) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }
}

bool isTemporaryIntegrationFailure(Object error) {
  if (error is! DioException) return false;

  final code = error.response?.statusCode;

  return code == 500 ||
      code == 502 ||
      code == 503 ||
      code == 504 ||
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
}

String friendlyIntegrationError(Object error) {
  if (error is DioException) {
    switch (error.response?.statusCode) {
      case 400:
        return 'The request was rejected.';

      case 401:
        return 'Your session has expired.';

      case 403:
        return 'You do not have permission for this operation.';

      case 404:
        return 'The requested integration is unavailable.';

      case 409:
        return 'The integration configuration has changed.';

      case 429:
        return 'Too many requests. Please try again later.';

      case 500:
      case 502:
      case 503:
      case 504:
        return 'The integration service is temporarily unavailable.';
    }

    if (isTemporaryIntegrationFailure(error)) {
      return 'Unable to reach the server.';
    }

    if (error.type == DioExceptionType.cancel) {
      return 'The request was cancelled.';
    }

    return 'The network request could not be completed.';
  }

  if (error is FormatException) {
    return 'Invalid integration information received.';
  }

  return 'An unexpected error occurred.';
}
