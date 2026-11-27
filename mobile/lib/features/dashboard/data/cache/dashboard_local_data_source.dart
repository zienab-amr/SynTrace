import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

class DashboardLocalDataSource {
  final _cache = CacheService.instance;

  static const _resourceType = 'dashboard';
  static const _teamCountKey = 'team_members_count';

  bool get isAvailable => _cache.isInitialized;

  int _decodeCount(dynamic json) {
    if (json is! int || json < 0) {
      throw const FormatException('Invalid cached team count.');
    }

    return json;
  }

  Future<CacheEntry<int>?> readTeamCount(CacheScope scope) async {
    if (!isAvailable) return null;

    return _cache.repository.read<int>(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: _teamCountKey,
      decode: _decodeCount,
      policy: CachePolicy.team,
    );
  }

  Stream<CacheEntry<int>?> watchTeamCount(CacheScope scope) {
    if (!isAvailable) {
      return Stream.value(null);
    }

    return _cache.repository.watch<int>(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: _teamCountKey,
      decode: _decodeCount,
      policy: CachePolicy.team,
    );
  }

  Future<void> saveTeamCount({
    required CacheScope scope,
    required CacheSessionGuard guard,
    required int count,
  }) async {
    if (!isAvailable) return;

    await _cache.repository.save<int>(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: _teamCountKey,
      data: count,
      encode: (value) => value,
      policy: CachePolicy.team,
      guard: guard,
    );
  }

  Future<void> invalidateTeamCount(CacheScope scope) async {
    if (!isAvailable) return;

    await _cache.repository.invalidate(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: _teamCountKey,
    );
  }
}
