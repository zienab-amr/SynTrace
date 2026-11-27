import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggerInterceptor extends Interceptor {
  static const _tag = 'SynTrace.Network';

  void _log(String message) {
    if (!kDebugMode) return;

    developer.log(message, name: _tag);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log('REQUEST ${options.method}');

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _log(
      'RESPONSE ${response.requestOptions.method} '
      'HTTP ${response.statusCode}',
    );

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(
      'ERROR ${err.requestOptions.method} '
      'HTTP ${err.response?.statusCode ?? '-'} '
      '${err.type.name}',
    );

    handler.next(err);
  }
}
