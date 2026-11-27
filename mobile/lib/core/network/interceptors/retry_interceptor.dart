import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 1),
  });

  static const _attemptKey = 'retry_attempt';

  static const allowRetryKey = 'allow_retry';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final method = request.method.toUpperCase();

    final isSafeRead = method == 'GET' || method == 'HEAD';

    final allowRetry = request.extra[allowRetryKey] == true;

    if (!isSafeRead || !allowRetry || !_shouldRetry(err)) {
      handler.next(err);
      return;
    }

    final attempt = request.extra[_attemptKey] as int? ?? 0;

    if (attempt >= maxRetries || request.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    request.extra[_attemptKey] = attempt + 1;

    await Future<void>.delayed(retryDelay * (attempt + 1));

    if (request.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    try {
      final response = await dio.fetch(request);

      handler.resolve(response);
    } on DioException catch (error) {
      handler.next(error);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _shouldRetry(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;

        return status == 502 || status == 503 || status == 504;

      default:
        return false;
    }
  }
}
