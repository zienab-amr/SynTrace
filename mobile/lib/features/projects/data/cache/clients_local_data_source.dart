import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import '../models/project_client_model.dart';

class ClientsLocalDataSource {
  final _cache = CacheService.instance;
  static const _type = 'clients';
  static const _key = 'directory';
  static const policy = CachePolicy(
    refreshAfter: Duration(minutes: 5),
    maxOfflineAge: Duration(hours: 24),
  );

  List<ProjectClientModel> _decode(dynamic json) {
    if (json is! List) throw const FormatException('Invalid clients cache.');
    return List.unmodifiable(
      json.map(
        (item) =>
            ProjectClientModel.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
    );
  }

  Future<CacheEntry<List<ProjectClientModel>>?> read(CacheScope scope) async {
    if (!_cache.isInitialized) return null;
    return _cache.repository.read<List<ProjectClientModel>>(
      scope: scope,
      resourceType: _type,
      resourceKey: _key,
      decode: _decode,
      policy: policy,
    );
  }

  Stream<CacheEntry<List<ProjectClientModel>>?> watch(CacheScope scope) {
    if (!_cache.isInitialized) return Stream.value(null);
    return _cache.repository.watch<List<ProjectClientModel>>(
      scope: scope,
      resourceType: _type,
      resourceKey: _key,
      decode: _decode,
      policy: policy,
    );
  }

  Future<void> save(
    CacheSessionGuard guard,
    List<ProjectClientModel> clients,
  ) async {
    if (!_cache.isInitialized) return;
    await _cache.repository.save<List<ProjectClientModel>>(
      scope: guard.scope,
      resourceType: _type,
      resourceKey: _key,
      data: clients,
      encode: (items) => items.map((item) => item.toJson()).toList(),
      policy: policy,
      guard: guard,
    );
  }

  Future<void> invalidate(CacheScope scope) async {
    if (!_cache.isInitialized) return;
    await _cache.repository.invalidateType(scope: scope, resourceType: _type);
  }
}
