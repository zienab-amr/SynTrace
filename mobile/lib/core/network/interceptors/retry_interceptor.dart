import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// Retry Interceptor
/// 
/// بيعيد الـ Request لما يحصل خطأ مؤقت
/// (Timeout, Network Error, 5xx)
/// ═══════════════════════════════════════════════════════════
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  });

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ─── هل نستحق إعادة المحاولة؟ ───
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    // ─── نجيب عدد المحاولات اللي تمت ───
    final attempt = err.requestOptions.extra['retry_attempt'] as int? ?? 0;

    // ─── لو استنفدنا كل المحاولات ───
    if (attempt >= maxRetries) {
      if (kDebugMode) {
        debugPrint('❌ Retry: Gave up after $attempt attempts');
      }
      return handler.next(err);
    }

    // ─── نزود العداد ───
    err.requestOptions.extra['retry_attempt'] = attempt + 1;

    // ─── استنى شوية (Exponential Backoff) ───
    final delay = retryDelay * (attempt + 1);
    
    if (kDebugMode) {
      debugPrint('🔄 Retry: Attempt ${attempt + 1}/$maxRetries '
          '(waiting ${delay.inSeconds}s)');
    }
    
    await Future.delayed(delay);

    try {
      // ─── جرب تاني ───
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// ═══════════════════════════════════════════════════════
  /// هل نستحق إعادة المحاولة؟
  /// ═══════════════════════════════════════════════════════
    // ─── 1. مشاكل الشبكة والـ Timeout ───
   bool _shouldRetry(DioException err) {
  switch (err.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:  // ← ضيفي ده
    case DioExceptionType.connectionError:
      return true;

    case DioExceptionType.badResponse:
      final statusCode = err.response?.statusCode ?? 0;
      return statusCode >= 500 && statusCode < 600;

    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return false;
  }
}
  
}