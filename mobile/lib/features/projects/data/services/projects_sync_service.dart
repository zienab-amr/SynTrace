import 'package:dio/dio.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../cache/projects_local_data_source.dart';
import '../models/project_api_model.dart';
import '../projects_repository.dart';

class ProjectsSyncService {
  ProjectsSyncService._();

  static final instance = ProjectsSyncService._();

  final _repository = ProjectsRepository();

  final local = ProjectsLocalDataSource();

  Future<List<ProjectApiModel>>? _inFlight;

  CacheSessionGuard? _activeGuard;

  Future<List<ProjectApiModel>> refresh({
    required CacheScope scope,
    CancelToken? cancelToken,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    final active = _inFlight;
    final activeGuard = _activeGuard;

    if (active != null &&
        activeGuard != null &&
        activeGuard.isValid &&
        activeGuard.scope == scope &&
        activeGuard.generation == guard.generation) {
      return active;
    }

    final operation = _refresh(
      scope: scope,
      guard: guard,
      cancelToken: cancelToken,
    );

    _inFlight = operation;
    _activeGuard = guard;

    try {
      return await operation;
    } finally {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
        _activeGuard = null;
      }
    }
  }

  Future<List<ProjectApiModel>> _refresh({
    required CacheScope scope,
    required CacheSessionGuard guard,
    CancelToken? cancelToken,
  }) async {
    guard.ensureValid();

    try {
      final projects = await _repository.getProjects(cancelToken: cancelToken);

      guard.ensureValid();

      final unique = <String, ProjectApiModel>{
        for (final project in projects) project.id: project,
      };

      final result = List<ProjectApiModel>.unmodifiable(unique.values);

      await local.saveProjects(scope: scope, guard: guard, projects: result);

      guard.ensureValid();

      return result;
    } on DioException catch (error) {
      final status = error.response?.statusCode;

      if (guard.isValid && (status == 401 || status == 403)) {
        await local.invalidateProjects(scope);
      }

      rethrow;
    }
  }
}
