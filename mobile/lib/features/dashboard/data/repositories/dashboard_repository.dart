import 'package:dio/dio.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/features/projects/data/models/project_api_model.dart';
import 'package:syntrace/features/projects/data/services/projects_sync_service.dart';

import '../models/dashboard_models.dart';
import '../services/dashboard_sync_service.dart';

class DashboardRepository {
  final projects = ProjectsSyncService.instance;
  final dashboard = DashboardSyncService.instance;

  Future<DashboardData> readCachedDashboard({required UserModel user}) async {
    final guard = _capture(user);
    final scope = guard.scope;

    final cachedProjects = await projects.local.readProjects(scope);

    final cachedTeam = user.isAdmin
        ? await dashboard.local.readTeamCount(scope)
        : null;

    guard.ensureValid();

    return DashboardData(
      projects: cachedProjects?.data,
      teamMembersCount: cachedTeam?.data,
    );
  }

  Future<DashboardData> loadDashboard({
    required UserModel user,
    CancelToken? cancelToken,
  }) async {
    final guard = _capture(user);
    final scope = guard.scope;

    final projectsFuture = _loadProjects(
      scope: scope,
      guard: guard,
      cancelToken: cancelToken,
    );

    final teamFuture = user.isAdmin
        ? _loadTeam(scope: scope, guard: guard, cancelToken: cancelToken)
        : Future.value(const _DashboardResult<int>());

    final projectResult = await projectsFuture;
    final teamResult = await teamFuture;

    guard.ensureValid();

    return DashboardData(
      projects: projectResult.data,
      teamMembersCount: teamResult.data,
      projectsError: projectResult.error,
      teamError: teamResult.error,
    );
  }

  Future<_DashboardResult<List<ProjectApiModel>>> _loadProjects({
    required CacheScope scope,
    required CacheSessionGuard guard,
    CancelToken? cancelToken,
  }) async {
    try {
      final items = await projects.refresh(
        scope: scope,
        cancelToken: cancelToken,
      );

      guard.ensureValid();

      return _DashboardResult(data: items);
    } catch (error) {
      if (!guard.isValid) {
        return const _DashboardResult();
      }

      if (_canUseCache(error)) {
        final cached = await projects.local.readProjects(scope);

        if (guard.isValid && cached != null) {
          return _DashboardResult(
            data: cached.data,
            error: 'Showing saved projects.',
          );
        }
      }

      return _DashboardResult(error: _message(error));
    }
  }

  Future<_DashboardResult<int>> _loadTeam({
    required CacheScope scope,
    required CacheSessionGuard guard,
    CancelToken? cancelToken,
  }) async {
    try {
      final count = await dashboard.refreshTeamCount(
        scope: scope,
        cancelToken: cancelToken,
      );

      guard.ensureValid();

      return _DashboardResult(data: count);
    } catch (error) {
      if (!guard.isValid) {
        return const _DashboardResult();
      }

      if (_canUseCache(error)) {
        final cached = await dashboard.local.readTeamCount(scope);

        if (guard.isValid && cached != null) {
          return _DashboardResult(
            data: cached.data,
            error: 'Showing saved team information.',
          );
        }
      }

      return _DashboardResult(error: _message(error));
    }
  }

  CacheSessionGuard _capture(UserModel user) {
    final scope = CacheScope.fromCurrentUser();
    final current = CurrentUserService.instance.user;

    if (scope == null ||
        scope.userId != user.id ||
        scope.tenantId != user.tenantId ||
        current?.role != user.role) {
      throw StateError('Session changed.');
    }

    return CacheSessionGuard.capture(scope);
  }

  bool _canUseCache(Object error) {
    if (error is! DioException) return false;

    final status = error.response?.statusCode;

    if (status != null && status >= 500) {
      return true;
    }

    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  String _message(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return 'Your session has expired.';
        case 403:
          return 'Access is restricted.';
        case 503:
          return 'The server is unavailable.';
      }
    }

    return 'Unable to refresh workspace data.';
  }
}

class _DashboardResult<T> {
  final T? data;
  final String? error;

  const _DashboardResult({this.data, this.error});
}
