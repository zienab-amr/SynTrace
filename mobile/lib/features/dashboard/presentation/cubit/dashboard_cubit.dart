import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/features/projects/data/models/project_api_model.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/repositories/dashboard_repository.dart';

import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;

  final _session = CurrentUserService.instance;

  DashboardCubit({DashboardRepository? repository})
    : _repository = repository ?? DashboardRepository(),
      super(DashboardInitial()) {
    _session.userNotifier.addListener(_onSessionChanged);
  }

  CacheSessionGuard? _guard;
  CancelToken? _cancelToken;

  StreamSubscription<CacheEntry<List<ProjectApiModel>>?>? _projectsSubscription;

  StreamSubscription<CacheEntry<int>?>? _teamSubscription;

  Timer? _projectsExpiryTimer;
  Timer? _teamExpiryTimer;

  DashboardData _data = const DashboardData();

  bool _isLoading = false;
  bool _isFromCache = false;

  bool _canPublish(CacheSessionGuard guard) {
    return !isClosed && identical(_guard, guard) && guard.isValid;
  }

  bool get _hasData => _data.projects != null || _data.teamMembersCount != null;

  void _onSessionChanged() {
    if (isClosed) return;

    if (_guard?.isValid == true) return;

    _reset();

    emit(DashboardInitial());

    if (_session.user != null) {
      unawaited(loadDashboard());
    }
  }

  void _reset() {
    _guard = null;

    _cancelToken?.cancel();
    _cancelToken = null;

    _cancelSubscriptions();

    _projectsExpiryTimer?.cancel();
    _teamExpiryTimer?.cancel();

    _data = const DashboardData();

    _isLoading = false;
    _isFromCache = false;
  }

  void _cancelSubscriptions() {
    final projects = _projectsSubscription;
    final team = _teamSubscription;

    _projectsSubscription = null;
    _teamSubscription = null;

    if (projects != null) {
      unawaited(projects.cancel());
    }

    if (team != null) {
      unawaited(team.cancel());
    }
  }

  Future<void> loadDashboard() async {
    if (isClosed || _isLoading) return;

    final user = _session.user;
    final scope = CacheScope.fromCurrentUser();

    if (user == null || scope == null) {
      emit(const DashboardError('Your workspace is unavailable.'));
      return;
    }

    if (_guard?.isValid != true) {
      _reset();

      try {
        _guard = CacheSessionGuard.capture(scope);
      } catch (_) {
        emit(const DashboardError('Your session is unavailable.'));
        return;
      }
    }

    final guard = _guard!;

    final token = CancelToken();
    _cancelToken = token;

    _isLoading = true;

    if (_hasData) {
      _publish();
    } else {
      emit(DashboardLoading());
    }

    try {
      _subscribe(guard: guard, isAdmin: user.isAdmin);

      final cached = await _repository.readCachedDashboard(user: user);

      if (!_canPublish(guard)) return;

      if (!_hasData &&
          (cached.projects != null || cached.teamMembersCount != null)) {
        _data = cached;
        _isFromCache = true;

        _publish();
      }

      final fresh = await _repository.loadDashboard(
        user: user,
        cancelToken: token,
      );

      if (!_canPublish(guard)) return;

      _data = fresh;

      _isFromCache =
          (fresh.projects != null && fresh.projectsError != null) ||
          (fresh.teamMembersCount != null && fresh.teamError != null);

      _publish();
    } catch (_) {
      if (!_canPublish(guard)) return;

      // Do not retain data after an unclassified
      // session or storage failure.
      _data = const DashboardData();

      emit(const DashboardError('Unable to load your workspace.'));
    } finally {
      if (_canPublish(guard)) {
        _isLoading = false;

        if (state is! DashboardError) {
          _publish();
        }
      }
    }
  }

  void _subscribe({required CacheSessionGuard guard, required bool isAdmin}) {
    final scope = guard.scope;

    if (_repository.projects.local.isAvailable) {
      _projectsSubscription ??= _repository.projects.local
          .watchProjects(scope)
          .listen(
            (entry) {
              if (!_canPublish(guard)) return;

              _data = DashboardData(
                projects: entry?.data,
                teamMembersCount: _data.teamMembersCount,
                projectsError: entry == null
                    ? 'Saved projects are unavailable.'
                    : null,
                teamError: _data.teamError,
              );

              _isFromCache = true;

              _scheduleProjectsExpiry(guard, entry?.expiresAt);

              _publishIfReady();
            },
            onError: (Object error) {
              if (!_canPublish(guard)) return;

              _clearProjects();
              _publishIfReady();
            },
          );
    }

    if (isAdmin && _repository.dashboard.local.isAvailable) {
      _teamSubscription ??= _repository.dashboard.local
          .watchTeamCount(scope)
          .listen(
            (entry) {
              if (!_canPublish(guard)) return;

              _data = DashboardData(
                projects: _data.projects,
                teamMembersCount: entry?.data,
                projectsError: _data.projectsError,
                teamError: entry == null
                    ? 'Saved team data is unavailable.'
                    : null,
              );

              _isFromCache = true;

              _scheduleTeamExpiry(guard, entry?.expiresAt);

              _publishIfReady();
            },
            onError: (Object error) {
              if (!_canPublish(guard)) return;

              _clearTeam();
              _publishIfReady();
            },
          );
    }
  }

  void _scheduleProjectsExpiry(CacheSessionGuard guard, DateTime? expiresAt) {
    _projectsExpiryTimer?.cancel();

    if (expiresAt == null) return;

    _projectsExpiryTimer = Timer(_remaining(expiresAt), () {
      if (!_canPublish(guard)) return;

      _clearProjects();
      _publishIfReady();
    });
  }

  void _scheduleTeamExpiry(CacheSessionGuard guard, DateTime? expiresAt) {
    _teamExpiryTimer?.cancel();

    if (expiresAt == null) return;

    _teamExpiryTimer = Timer(_remaining(expiresAt), () {
      if (!_canPublish(guard)) return;

      _clearTeam();
      _publishIfReady();
    });
  }

  Duration _remaining(DateTime expiresAt) {
    final duration = expiresAt.difference(DateTime.now().toUtc());

    return duration.isNegative ? Duration.zero : duration;
  }

  void _clearProjects() {
    _data = DashboardData(
      teamMembersCount: _data.teamMembersCount,
      projectsError: 'Saved projects are unavailable.',
      teamError: _data.teamError,
    );
  }

  void _clearTeam() {
    _data = DashboardData(
      projects: _data.projects,
      projectsError: _data.projectsError,
      teamError: 'Saved team data is unavailable.',
    );
  }

  void _publishIfReady() {
    if (_isLoading && !_hasData) return;

    _publish();
  }

  void _publish() {
    if (isClosed || _guard?.isValid != true) {
      return;
    }

    emit(
      DashboardLoaded(
        data: _data,
        isRefreshing: _isLoading,
        isFromCache: _isFromCache,
      ),
    );
  }

  Future<void> refresh() => loadDashboard();

  @override
  Future<void> close() async {
    _session.userNotifier.removeListener(_onSessionChanged);

    _guard = null;

    _cancelToken?.cancel();

    _projectsExpiryTimer?.cancel();
    _teamExpiryTimer?.cancel();

    await _projectsSubscription?.cancel();
    await _teamSubscription?.cancel();

    await super.close();
  }
}
