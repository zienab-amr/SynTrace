import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_policy.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_service.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../models/project_api_model.dart';
import 'project_cache_keys.dart';

class ProjectsLocalDataSource {
  final _cache = CacheService.instance;

  bool get isAvailable => _cache.isInitialized;

  List<ProjectApiModel> _decodeProjects(dynamic json) {
    if (json is! List) {
      throw const FormatException('Invalid cached projects.');
    }

    return List.unmodifiable(
      json.map(
        (item) =>
            ProjectApiModel.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
    );
  }

  Future<CacheEntry<List<ProjectApiModel>>?> readProjects(
    CacheScope scope,
  ) async {
    if (!isAvailable) return null;

    return _cache.repository.read<List<ProjectApiModel>>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.list,
      decode: _decodeProjects,
      policy: CachePolicy.projects,
    );
  }

  Future<CacheEntry<ProjectApiModel>?> readProjectDetails({
    required CacheScope scope,
    required String projectId,
  }) async {
    if (!isAvailable) return null;

    return _cache.repository.read<ProjectApiModel>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.details(projectId),
      decode: (json) =>
          ProjectApiModel.fromJson(Map<String, dynamic>.from(json as Map)),
      policy: CachePolicy.projects,
    );
  }

  Stream<CacheEntry<ProjectApiModel>?> watchProjectDetails({
    required CacheScope scope,
    required String projectId,
  }) {
    if (!isAvailable) {
      return Stream.value(null);
    }

    return _cache.repository.watch<ProjectApiModel>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.details(projectId),
      decode: (json) =>
          ProjectApiModel.fromJson(Map<String, dynamic>.from(json as Map)),
      policy: CachePolicy.projects,
    );
  }

  Future<void> saveProjectDetails({
    required CacheScope scope,
    required CacheSessionGuard guard,
    required ProjectApiModel project,
  }) async {
    if (!isAvailable) return;

    await _cache.repository.save<ProjectApiModel>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.details(project.id),
      data: project,
      encode: (item) => item.toJson(),
      policy: CachePolicy.projects,
      guard: guard,
    );
  }

  Future<void> invalidateProjectDetails({
    required CacheScope scope,
    required String projectId,
  }) async {
    if (!isAvailable) return;

    await _cache.repository.invalidate(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.details(projectId),
    );
  }

  Stream<CacheEntry<List<ProjectApiModel>>?> watchProjects(CacheScope scope) {
    if (!isAvailable) {
      return Stream.value(null);
    }

    return _cache.repository.watch<List<ProjectApiModel>>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.list,
      decode: _decodeProjects,
      policy: CachePolicy.projects,
    );
  }

  Future<void> saveProjects({
    required CacheScope scope,
    required CacheSessionGuard guard,
    required List<ProjectApiModel> projects,
  }) async {
    if (!isAvailable) return;

    await _cache.repository.save<List<ProjectApiModel>>(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
      resourceKey: ProjectCacheKeys.list,
      data: projects,
      encode: (items) => items.map((item) => item.toJson()).toList(),
      policy: CachePolicy.projects,
      guard: guard,
    );
  }

  Future<void> invalidateProjects(CacheScope scope) async {
    if (!isAvailable) return;

    await _cache.repository.invalidateType(
      scope: scope,
      resourceType: ProjectCacheKeys.resourceType,
    );
  }
}
