import 'package:drift/drift.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/database/app_database.dart';

class CacheDao {
  final AppDatabase database;

  const CacheDao(this.database);

  Future<CachedResource?> read({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
  }) {
    final query = database.select(database.cachedResources);

    query.where(
      (table) =>
          table.tenantId.equals(scope.tenantId) &
          table.userId.equals(scope.userId) &
          table.resourceType.equals(resourceType) &
          table.resourceKey.equals(resourceKey),
    );

    return query.getSingleOrNull();
  }

  Future<void> write({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
    required String encryptedPayload,
    required DateTime syncedAt,
    DateTime? expiresAt,
    int version = 1,
  }) async {
    await database
        .into(database.cachedResources)
        .insertOnConflictUpdate(
          CachedResourcesCompanion.insert(
            tenantId: scope.tenantId,
            userId: scope.userId,
            resourceType: resourceType,
            resourceKey: resourceKey,
            payload: encryptedPayload,
            payloadVersion: Value(version),
            syncedAt: syncedAt.toUtc(),
            expiresAt: Value(expiresAt?.toUtc()),
          ),
        );
  }

  Future<void> delete({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
  }) async {
    final query = database.delete(database.cachedResources);

    query.where(
      (table) =>
          table.tenantId.equals(scope.tenantId) &
          table.userId.equals(scope.userId) &
          table.resourceType.equals(resourceType) &
          table.resourceKey.equals(resourceKey),
    );

    await query.go();
  }

  Future<void> deleteResourceType({
    required CacheScope scope,
    required String resourceType,
  }) async {
    final query = database.delete(database.cachedResources);

    query.where(
      (table) =>
          table.tenantId.equals(scope.tenantId) &
          table.userId.equals(scope.userId) &
          table.resourceType.equals(resourceType),
    );

    await query.go();
  }

  Future<void> clearAccount(CacheScope scope) async {
    final query = database.delete(database.cachedResources);

    query.where(
      (table) =>
          table.tenantId.equals(scope.tenantId) &
          table.userId.equals(scope.userId),
    );

    await query.go();
  }

  Stream<CachedResource?> watch({
    required CacheScope scope,
    required String resourceType,
    required String resourceKey,
  }) {
    final query = database.select(database.cachedResources);

    query.where(
      (table) =>
          table.tenantId.equals(scope.tenantId) &
          table.userId.equals(scope.userId) &
          table.resourceType.equals(resourceType) &
          table.resourceKey.equals(resourceKey),
    );

    return query.watchSingleOrNull();
  }

  Future<int> deleteExpired() async {
    final query = database.delete(database.cachedResources);

    query.where(
      (table) =>
          table.expiresAt.isNotNull() &
          table.expiresAt.isSmallerOrEqualValue(DateTime.now().toUtc()),
    );

    return query.go();
  }
}
