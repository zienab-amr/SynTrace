import 'dart:convert';

import 'package:syntrace/core/cache/cache_encryption_service.dart';
import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_operation_lock.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/database/daos/cache_dao.dart';

class CacheRepository {
  final CacheDao dao;
  final CacheEncryptionService encryption;

  final _lock = CacheOperationLock.instance;

  CacheRepository({required this.dao, CacheEncryptionService? encryption})
    : encryption = encryption ?? CacheEncryptionService.instance;

  Future<void> save<T>({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required T data,
    required Object? Function(T data) encode,
    required CachePolicy policy,
    required CacheSessionGuard guard,
    int version = 1,
  }) async {
    _validateGuard(scope, guard);

    final payload = jsonEncode(encode(data));

    await _lock.run(() async {
      _validateGuard(scope, guard);

      final encrypted = await encryption.encrypt(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
        plaintext: payload,
        version: version,
      );

      _validateGuard(scope, guard);

      final now = DateTime.now().toUtc();

      await dao.write(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
        encryptedPayload: encrypted,
        syncedAt: now,
        expiresAt: now.add(policy.maxOfflineAge),
        version: version,
      );
    });
  }

  Future<CacheEntry<T>?> read<T>({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required T Function(dynamic json) decode,
    required CachePolicy policy,
    int version = 1,
  }) async {
    try {
      final guard = CacheSessionGuard.capture(scope);

      return await _readWithGuard<T>(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
        decode: decode,
        policy: policy,
        guard: guard,
        version: version,
      );
    } catch (_) {
      return null;
    }
  }

  Future<CacheEntry<T>?> _readWithGuard<T>({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required T Function(dynamic json) decode,
    required CachePolicy policy,
    required CacheSessionGuard guard,
    required int version,
  }) async {
    return _lock.run(() async {
      if (!guard.isValid) return null;

      final resource = await dao.read(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
      );

      if (resource == null ||
          !guard.isValid ||
          resource.payloadVersion != version) {
        return null;
      }

      final now = DateTime.now().toUtc();
      final expiresAt = resource.expiresAt;

      if (expiresAt != null && !now.isBefore(expiresAt.toUtc())) {
        return null;
      }

      if (!policy.canReadOffline(resource.syncedAt, now: now)) {
        return null;
      }

      try {
        final plaintext = await encryption.decrypt(
          scope: scope,
          resourceType: resourceType,
          resourceKey: resourceKey,
          encrypted: resource.payload,
          version: version,
        );

        if (!guard.isValid) return null;

        final data = decode(jsonDecode(plaintext));
        final readAt = DateTime.now().toUtc();
        if (!guard.isValid ||
            (expiresAt != null && !readAt.isBefore(expiresAt.toUtc())) ||
            !policy.canReadOffline(resource.syncedAt, now: readAt)) {
          return null;
        }

        return CacheEntry<T>(
          data: data,
          syncedAt: resource.syncedAt,
          expiresAt: expiresAt,
          isStale: policy.needsRefresh(resource.syncedAt, now: readAt),
        );
      } catch (_) {
        return null;
      }
    });
  }

  Stream<CacheEntry<T>?> watch<T>({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required T Function(dynamic json) decode,
    required CachePolicy policy,
    int version = 1,
  }) {
    final guard = CacheSessionGuard.capture(scope);

    return dao
        .watch(
          scope: scope,
          resourceType: resourceType,
          resourceKey: resourceKey,
        )
        .asyncMap(
          (_) => _readWithGuard<T>(
            scope: scope,
            resourceType: resourceType,
            resourceKey: resourceKey,
            decode: decode,
            policy: policy,
            guard: guard,
            version: version,
          ),
        );
  }

  Future<void> invalidate({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    await _lock.run(() async {
      guard.ensureValid();

      await dao.delete(
        scope: scope,
        resourceType: resourceType,
        resourceKey: resourceKey,
      );
    });
  }

  Future<void> invalidateType({
    required CacheScope scope,
    required String resourceType,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    await _lock.run(() async {
      guard.ensureValid();

      await dao.deleteResourceType(scope: scope, resourceType: resourceType);
    });
  }

  // The session owner must hold the operation lock.
  Future<void> clearAccount(CacheScope scope) async {
    try {
      await encryption.deleteKey(scope);
    } finally {
      await dao.clearAccount(scope);
    }
  }

  void _validateGuard(CacheScope scope, CacheSessionGuard guard) {
    if (guard.scope != scope) {
      throw StateError('Cache scope mismatch.');
    }

    guard.ensureValid();
  }
}
