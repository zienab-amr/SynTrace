import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:syntrace/core/cache/cache_session.dart';
import 'package:syntrace/core/cache/cache_operation_lock.dart';
import 'package:syntrace/core/network/api_endpoints.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/features/auth/data/models/auth_models.dart';

enum RefreshOutcome {
  refreshed,
  rejected,
  unavailable,
  sessionChanged,
  uncertain,
}

class TokenRefreshService {
  TokenRefreshService._();
  static final instance = TokenRefreshService._();
  final _storage = SecureStorageService.instance;
  final _session = CacheSession.instance;
  final _current = CurrentUserService.instance;
  final _dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      validateStatus: (status) => status != null,
    ),
  );
  Future<RefreshOutcome>? _flight;
  int? _flightGeneration;
  int? _uncertainGeneration;

  Future<RefreshOutcome> refresh({
    required String failedAccessToken,
    required int generation,
  }) async {
    if (_session.isBlocked || _session.generation != generation) {
      return RefreshOutcome.sessionChanged;
    }
    if (_flight != null) {
      if (_flightGeneration != generation) return RefreshOutcome.sessionChanged;
      return _flight!;
    }
    if (_uncertainGeneration == generation) return RefreshOutcome.uncertain;
    _flightGeneration = generation;
    final flight = _perform(failedAccessToken, generation);
    _flight = flight;
    try {
      return await flight;
    } finally {
      _flight = null;
      _flightGeneration = null;
    }
  }

  Future<RefreshOutcome> _perform(String failedToken, int generation) async {
    final user = _current.user;
    bool valid() =>
        !_session.isBlocked &&
        _session.generation == generation &&
        user != null &&
        _current.user?.id == user.id &&
        _current.user?.tenantId == user.tenantId;
    if (!valid()) return RefreshOutcome.sessionChanged;
    var sent = false;
    try {
      final access = await _storage.getToken();
      final refresh = await _storage.getRefreshToken();
      if (!valid()) return RefreshOutcome.sessionChanged;
      if (access == null || refresh == null || refresh.isEmpty) {
        await _current.clearUser(expectedGeneration: generation);
        return RefreshOutcome.rejected;
      }
      if (access != failedToken) return RefreshOutcome.refreshed;
      final prepared = await CacheOperationLock.instance.run(() async {
        if (!valid()) return false;
        if (await _storage.hasPendingRotation()) return false;
        if (!valid()) return false;
        await _storage.markRotationPending();
        return valid();
      });
      if (!valid()) return RefreshOutcome.sessionChanged;
      if (!prepared) return RefreshOutcome.uncertain;
      sent = true;
      final response = await _dio.post(
        ApiEndpoints.refreshToken,
        data: {'refreshToken': refresh},
      );
      if (!valid()) return RefreshOutcome.sessionChanged;
      final status = response.statusCode;
      if (status == 401 || status == 403) {
        await _current.clearUser(expectedGeneration: generation);
        return RefreshOutcome.rejected;
      }
      if (status == 429) {
        await CacheOperationLock.instance.run(() async {
          if (valid()) await _storage.clearRotationPending();
        });
        return RefreshOutcome.unavailable;
      }
      if (status != 200 || response.data is! Map) {
        _uncertainGeneration = generation;
        await _current.clearUser(expectedGeneration: generation);
        return RefreshOutcome.uncertain;
      }
      final tokens = AuthResponse.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      final updated = tokens.extractUser();
      if (tokens.refreshTokenExpiration == null ||
          !tokens.refreshTokenExpiration!.isAfter(DateTime.now().toUtc()) ||
          tokens.accessToken.isEmpty ||
          tokens.refreshToken.isEmpty ||
          tokens.refreshToken == refresh ||
          updated == null ||
          updated.id != user!.id ||
          updated.tenantId != user.tenantId ||
          !listEquals(updated.roleNames, user.roleNames)) {
        _uncertainGeneration = generation;
        await _current.clearUser(expectedGeneration: generation);
        return RefreshOutcome.uncertain;
      }
      return await CacheOperationLock.instance.run(() async {
        if (!valid() ||
            await _storage.getRefreshToken() != refresh ||
            !valid()) {
          return RefreshOutcome.sessionChanged;
        }
        await _storage.saveTokenPair(
          tokens.accessToken,
          tokens.refreshToken,
          verifiedAt: DateTime.now().toUtc(),
          refreshExpiresAt: tokens.refreshTokenExpiration,
        );
        if (valid()) await _storage.clearRotationPending();
        return valid()
            ? RefreshOutcome.refreshed
            : RefreshOutcome.sessionChanged;
      });
    } catch (_) {
      if (!valid()) return RefreshOutcome.sessionChanged;
      if (sent) {
        _uncertainGeneration = generation;
        await _current.clearUser(expectedGeneration: generation);
        return RefreshOutcome.uncertain;
      }
      return RefreshOutcome.unavailable;
    }
  }
}
