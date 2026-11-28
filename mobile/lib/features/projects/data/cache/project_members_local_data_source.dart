import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../models/project_team_member.dart';

class ProjectMembersLocalDataSource {
  final _cache = CacheService.instance;

  static const _resourceType = 'project_members';

  Future<CacheEntry<List<ProjectTeamMember>>?> read({
    required CacheScope scope,
    required String projectId,
  }) async {
    if (!_cache.isInitialized) return null;

    return _cache.repository.read<List<ProjectTeamMember>>(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: projectId,
      policy: CachePolicy.team,
      decode: (json) {
        if (json is! List) {
          throw const FormatException('Invalid saved members.');
        }

        return List<ProjectTeamMember>.unmodifiable(
          json.map((item) {
            final map = Map<String, dynamic>.from(item as Map);

            return ProjectTeamMember(
              employeeId: map['employeeId'] as String,
              name: map['name'] as String,
              email: map['email'] as String,
              role: ProjectMemberRole.fromJson(map['role']),
            );
          }),
        );
      },
    );
  }

  Future<void> save({
    required CacheSessionGuard guard,
    required String projectId,
    required List<ProjectTeamMember> members,
  }) async {
    if (!_cache.isInitialized) return;

    guard.ensureValid();

    await _cache.repository.save<List<ProjectTeamMember>>(
      scope: guard.scope,
      resourceType: _resourceType,
      resourceKey: projectId,
      data: members,
      policy: CachePolicy.team,
      guard: guard,
      encode: (items) => items.map((member) {
        return {
          'employeeId': member.employeeId,
          'name': member.name,
          'email': member.email,
          'role': member.role.apiValue,
        };
      }).toList(),
    );
  }

  Future<void> invalidate({
    required CacheScope scope,
    required String projectId,
  }) async {
    if (!_cache.isInitialized) return;

    await _cache.repository.invalidate(
      scope: scope,
      resourceType: _resourceType,
      resourceKey: projectId,
    );
  }
}
