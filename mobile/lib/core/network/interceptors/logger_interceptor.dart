import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════
/// Logger Interceptor
/// 
/// بيطبع كل Request و Response في الـ Console
/// بيشتغل بس في وضع الـ Debug
/// ═══════════════════════════════════════════════════════════
class LoggerInterceptor extends Interceptor {
  
  static const _tag = '🌐 API';

  /// ═══════════════════════════════════════════════════════
  /// 1. قبل الـ Request
  /// ═══════════════════════════════════════════════════════
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // بيشتغل بس في الـ Debug Mode
    if (!kDebugMode) return handler.next(options);

    developer.log(
      '🚀 REQUEST',
      name: _tag,
      time: DateTime.now(),
    );
    developer.log(
      '   Method  : ${options.method}',
      name: _tag,
    );
    developer.log(
      '   URL     : ${options.uri}',
      name: _tag,
    );
    
    if (options.queryParameters.isNotEmpty) {
      developer.log(
        '   Query   : ${options.queryParameters}',
        name: _tag,
      );
    }
    
    if (options.headers.isNotEmpty) {
      // نمسح الـ Token عشان ميتطبعش كامل
      final safeHeaders = Map<String, dynamic>.from(options.headers);
      if (safeHeaders.containsKey('Authorization')) {
        final auth = safeHeaders['Authorization'].toString();
        safeHeaders['Authorization'] = '${auth.substring(0, 20)}...';
      }
      developer.log(
        '   Headers : $safeHeaders',
        name: _tag,
      );
    }
    
    if (options.data != null) {
      developer.log(
        '   Body    : ${options.data}',
        name: _tag,
      );
    }

    developer.log('', name: _tag);
    handler.next(options);
  }

  /// ═══════════════════════════════════════════════════════
  /// 2. بعد الـ Response
  /// ═══════════════════════════════════════════════════════
  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    if (!kDebugMode) return handler.next(response);

    developer.log(
      '✅ RESPONSE ${response.statusCode}',
      name: _tag,
      time: DateTime.now(),
    );
    developer.log(
      '   URL     : ${response.requestOptions.uri}',
      name: _tag,
    );
    developer.log(
      '   Data    : ${response.data}',
      name: _tag,
    );
    developer.log('', name: _tag);

    handler.next(response);
  }

  /// ═══════════════════════════════════════════════════════
  /// 3. لما يحصل خطأ
  /// ═══════════════════════════════════════════════════════
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (!kDebugMode) return handler.next(err);

    developer.log(
      '❌ ERROR',
      name: _tag,
      time: DateTime.now(),
      error: err.message,
    );
    developer.log(
      '   URL     : ${err.requestOptions.uri}',
      name: _tag,
    );
    developer.log(
      '   Type    : ${err.type}',
      name: _tag,
    );
    
    if (err.response != null) {
      developer.log(
        '   Status  : ${err.response?.statusCode}',
        name: _tag,
      );
      developer.log(
        '   Data    : ${err.response?.data}',
        name: _tag,
      );
    }
    
    developer.log('', name: _tag);

    handler.next(err);
  }
}