import 'package:dio/dio.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/network/services/token_refresh_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.dio});
  final Dio dio;
  final _storage = SecureStorageService.instance;
  final _session = CacheSession.instance;
  static const _generation = 'auth_generation';
  static const _retried = 'auth_retried';

  bool _public(RequestOptions r) =>
      const {
        ApiEndpoints.login,
        ApiEndpoints.register,
        ApiEndpoints.sendOtp,
        ApiEndpoints.verifyOtp,
        ApiEndpoints.resetPassword,
        ApiEndpoints.refreshToken,
      }.any(
        (path) =>
            r.uri.path.toLowerCase() ==
            '${Uri.parse(ApiEndpoints.baseUrl).path}$path'.toLowerCase(),
      );

  bool _trusted(RequestOptions r) {
    final base = Uri.parse(ApiEndpoints.baseUrl);
    return r.uri.origin == base.origin &&
        r.uri.path.startsWith('${base.path}/');
  }

  bool _same(RequestOptions r) => r.extra[_generation] == _session.generation;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (!_trusted(options)) {
        throw StateError('Unexpected API destination');
      }
      options.followRedirects = false;
      options.headers.removeWhere(
        (key, _) =>
            key.toLowerCase() == 'authorization' ||
            key.toLowerCase() == 'x-tenant-id',
      );
      if (!_public(options)) {
        options.extra.putIfAbsent(_generation, () => _session.generation);
        final token = await _storage.getToken();
        final tenant = await _storage.getTenantId();
        if (_session.isBlocked ||
            !_same(options) ||
            options.cancelToken?.isCancelled == true) {
          throw StateError('Session changed or request cancelled');
        }
        if (token == null ||
            token.isEmpty ||
            tenant == null ||
            tenant.isEmpty) {
          throw StateError('Missing session credentials');
        }
        if (token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (tenant.isNotEmpty) {
          options.headers['X-Tenant-Id'] = tenant;
        }
      }
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'Request blocked',
        ),
      );
    }
  }

  Future<Response<dynamic>?> _recover(RequestOptions r) async {
    if (!_trusted(r) ||
        _public(r) ||
        r.path == ApiEndpoints.logout ||
        r.extra[_retried] == true ||
        !_same(r) ||
        _session.isBlocked ||
        r.cancelToken?.isCancelled == true) {
      return null;
    }
    final header = r.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    final outcome = await TokenRefreshService.instance.refresh(
      failedAccessToken: header.substring(7),
      generation: r.extra[_generation] as int,
    );
    if (outcome != RefreshOutcome.refreshed ||
        !_same(r) ||
        _session.isBlocked ||
        r.cancelToken?.isCancelled == true) {
      return null;
    }
    // Never automatically replay mutations or streamed bodies.
    if (!const {'GET', 'HEAD'}.contains(r.method.toUpperCase()) ||
        r.data != null) {
      return null;
    }
    r.extra[_retried] = true;
    return dio.fetch<dynamic>(r);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final r = response.requestOptions;
    if (!_public(r) && !_same(r)) {
      handler.reject(
        DioException(
          requestOptions: r,
          type: DioExceptionType.cancel,
          message: 'Session changed',
        ),
      );
      return;
    }
    if (response.statusCode == 401) {
      try {
        final recovered = await _recover(r);
        if (recovered != null) {
          handler.resolve(recovered);
          return;
        }
      } on DioException catch (e) {
        handler.reject(e);
        return;
      } catch (_) {
        /* Preserve original response. */
      }
    }
    if (!_public(r) && !_same(r)) {
      handler.reject(
        DioException(
          requestOptions: r,
          type: DioExceptionType.cancel,
          message: 'Session changed',
        ),
      );
      return;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_public(err.requestOptions) && !_same(err.requestOptions)) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Session changed',
        ),
      );
      return;
    }
    if (err.response?.statusCode == 401) {
      try {
        final recovered = await _recover(err.requestOptions);
        if (recovered != null) {
          handler.resolve(recovered);
          return;
        }
      } on DioException catch (e) {
        handler.next(e);
        return;
      } catch (_) {
        /* Preserve original error. */
      }
    }
    if (!_public(err.requestOptions) && !_same(err.requestOptions)) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          type: DioExceptionType.cancel,
          message: 'Session changed',
        ),
      );
      return;
    }
    handler.next(err);
  }
}
