import 'package:dio/dio.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';

import '../cache/projects_local_data_source.dart';
import '../models/project_api_model.dart';
import '../projects_repository.dart';

class ProjectDetailsSyncService {
  ProjectDetailsSyncService._();

  static final instance = ProjectDetailsSyncService._();

  final _repository = ProjectsRepository();

  final local = ProjectsLocalDataSource();

  final Map<String, Future<ProjectApiModel>> _inFlight = {};

  Future<ProjectApiModel> refresh({
    required CacheScope scope,
    required String projectId,
    CancelToken? cancelToken,
  }) async {
    final guard = CacheSessionGuard.capture(scope);

    final key = '${guard.generation}:$projectId';

    final existing = _inFlight[key];

    if (existing != null) {
      return existing;
    }

    final operation = _refresh(
      scope: scope,
      guard: guard,
      projectId: projectId,
      cancelToken: cancelToken,
    );

    _inFlight[key] = operation;

    try {
      return await operation;
    } finally {
      if (identical(_inFlight[key], operation)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<ProjectApiModel> _refresh({
    required CacheScope scope,
    required CacheSessionGuard guard,
    required String projectId,
    CancelToken? cancelToken,
  }) async {
    guard.ensureValid();

    try {
      final project = await _repository.getProjectById(
        projectId,
        cancelToken: cancelToken,
      );

      guard.ensureValid();

      await local.saveProjectDetails(
        scope: scope,
        guard: guard,
        project: project,
      );

      guard.ensureValid();

      return project;
    } on DioException catch (error) {
      final status = error.response?.statusCode;

      if (guard.isValid && (status == 401 || status == 403 || status == 404)) {
        await local.invalidateProjectDetails(
          scope: scope,
          projectId: projectId,
        );
      }

      rethrow;
    }
  }
}
