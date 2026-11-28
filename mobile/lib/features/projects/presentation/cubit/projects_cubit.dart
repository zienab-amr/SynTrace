import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import '../../data/models/project_api_model.dart';
import '../../data/projects_repository.dart';
import '../../data/services/projects_sync_service.dart';

import 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  final ProjectsRepository? _repository;

  final _sync = ProjectsSyncService.instance;
  final _session = CurrentUserService.instance;

  ProjectsCubit({ProjectsRepository? repository})
    : _repository = repository,
      super(const ProjectsInitial()) {
    _session.userNotifier.addListener(_onSessionChanged);
  }

  List<ProjectApiModel> _allProjects = [];

  String _searchQuery = '';
  ProjectApiStatus? _selectedStatus;

  CacheSessionGuard? _guard;

  StreamSubscription<CacheEntry<List<ProjectApiModel>>?>? _subscription;

  Timer? _expiryTimer;

  bool _isLoading = false;
  bool _hasData = false;
  bool _isFromCache = false;
  bool _isStale = false;

  DateTime? _lastSyncedAt;
  String? _syncError;

  bool _canPublish(CacheSessionGuard guard) {
    return !isClosed && identical(_guard, guard) && guard.isValid;
  }

  void _onSessionChanged() {
    if (_guard?.isValid == true) return;

    _reset();

    if (!isClosed) {
      emit(const ProjectsInitial());
    }
  }

  void _reset() {
    _guard = null;

    _expiryTimer?.cancel();
    _expiryTimer = null;

    final subscription = _subscription;
    _subscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _allProjects = [];
    _searchQuery = '';
    _selectedStatus = null;

    _isLoading = false;
    _hasData = false;
    _isFromCache = false;
    _isStale = false;

    _lastSyncedAt = null;
    _syncError = null;
  }

  Future<void> loadProjects() async {
    if (isClosed || _isLoading) return;

    final scope = CacheScope.fromCurrentUser();

    if (scope == null) {
      emit(const ProjectsError('Your session is unavailable.'));
      return;
    }

    if (_guard?.isValid != true) {
      _reset();

      try {
        _guard = CacheSessionGuard.capture(scope);
      } catch (_) {
        emit(const ProjectsError('Your session is unavailable.'));
        return;
      }
    }

    final guard = _guard!;

    _isLoading = true;
    _syncError = null;

    if (_hasData) {
      _emitFiltered();
    } else {
      emit(const ProjectsLoading());
    }

    try {
      if (!_hasData && _repository == null) {
        final cached = await _sync.local.readProjects(scope);

        if (!_canPublish(guard)) return;

        if (cached != null) {
          _applyCache(cached, guard);
        }
      }

      if (_repository == null) {
        _subscription ??= _sync.local
            .watchProjects(scope)
            .listen(
              (entry) {
                if (!_canPublish(guard)) return;

                if (entry == null) {
                  _clearVisibleData();

                  if (!_isLoading) {
                    emit(
                      const ProjectsError('Saved project data is unavailable.'),
                    );
                  }

                  return;
                }

                _applyCache(entry, guard);
              },
              onError: (Object error) {
                if (!_canPublish(guard)) return;

                _syncError = 'Local project storage is unavailable.';

                if (_hasData) {
                  _emitFiltered();
                }
              },
            );
      }

      final projects = _repository != null
          ? await _repository.getProjects()
          : await _sync.refresh(scope: scope);

      if (!_canPublish(guard)) return;

      _allProjects = List.unmodifiable(projects);
      _hasData = true;
      _isFromCache = false;
      _isStale = false;
      _lastSyncedAt = DateTime.now().toUtc();
      _syncError = null;

      _scheduleExpiry(guard, _lastSyncedAt!.add(const Duration(hours: 24)));

      _emitFiltered();
    } catch (error) {
      if (!_canPublish(guard)) return;

      final status = error is DioException ? error.response?.statusCode : null;

      if (status == 401 || status == 403) {
        _clearVisibleData();

        emit(ProjectsError(_getErrorMessage(error)));
        return;
      }

      if (_hasData && _canUseCachedData(error)) {
        _isFromCache = true;
        _isStale = true;
        _syncError = _getErrorMessage(error);

        _emitFiltered();
      } else {
        _clearVisibleData();

        emit(ProjectsError(_getErrorMessage(error)));
      }
    } finally {
      if (_canPublish(guard)) {
        _isLoading = false;

        if (_hasData) {
          _emitFiltered();
        }
      }
    }
  }

  void _applyCache(
    CacheEntry<List<ProjectApiModel>> entry,
    CacheSessionGuard guard,
  ) {
    if (!_canPublish(guard)) return;

    if (_lastSyncedAt != null && entry.syncedAt.isBefore(_lastSyncedAt!)) {
      return;
    }

    _allProjects = List.unmodifiable(entry.data);
    _hasData = true;

    _isFromCache = true;
    _isStale = entry.isStale;

    _lastSyncedAt = entry.syncedAt;

    if (!entry.isStale) {
      _syncError = null;
    }

    _scheduleExpiry(guard, entry.expiresAt);

    _emitFiltered();
  }

  void _scheduleExpiry(CacheSessionGuard guard, DateTime? expiresAt) {
    _expiryTimer?.cancel();

    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now().toUtc());

    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!_canPublish(guard)) return;

      _clearVisibleData();

      emit(
        const ProjectsError(
          'Saved projects have expired. '
          'Connect to refresh your workspace.',
        ),
      );
    });
  }

  void _clearVisibleData() {
    _expiryTimer?.cancel();

    _allProjects = [];
    _hasData = false;
    _isFromCache = false;
    _isStale = false;
    _lastSyncedAt = null;
    _syncError = null;
  }

  bool _canUseCachedData(Object error) {
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

  void search(String query) {
    if (isClosed) return;

    _searchQuery = query;

    if (_hasData) {
      _emitFiltered();
    }
  }

  void filterByStatus(ProjectApiStatus? status) {
    if (isClosed) return;

    _selectedStatus = status;

    if (_hasData) {
      _emitFiltered();
    }
  }

  void clearFilters() {
    if (isClosed) return;

    _searchQuery = '';
    _selectedStatus = null;

    if (_hasData) {
      _emitFiltered();
    }
  }

  Future<void> refresh() => loadProjects();

  void _emitFiltered() {
    if (isClosed || !_hasData || _guard?.isValid != true) {
      return;
    }

    final query = _searchQuery.trim().toLowerCase();

    final filtered = _allProjects.where((project) {
      final matchesStatus =
          _selectedStatus == null || project.status == _selectedStatus;

      final matchesSearch =
          query.isEmpty ||
          project.name.toLowerCase().contains(query) ||
          (project.description ?? '').toLowerCase().contains(query);

      return matchesStatus && matchesSearch;
    }).toList();

    emit(
      ProjectsLoaded(
        projects: List.unmodifiable(filtered),
        searchQuery: _searchQuery,
        selectedStatus: _selectedStatus,
        totalCount: _allProjects.length,
        isRefreshing: _isLoading,
        isFromCache: _isFromCache,
        isStale: _isStale,
        lastSyncedAt: _lastSyncedAt,
        syncError: _syncError,
      ),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return 'Your session has expired.';
        case 403:
          return 'You do not have access to these projects.';
        case 503:
          return 'The server is temporarily unavailable.';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'No connection to the server.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The connection timed out.';
      }
    }

    if (error is FormatException) {
      return 'Invalid project data received.';
    }

    return 'Unable to load projects. Please try again.';
  }

  @override
  Future<void> close() async {
    _session.userNotifier.removeListener(_onSessionChanged);

    final subscription = _subscription;

    _subscription = null;
    _guard = null;

    _expiryTimer?.cancel();

    await subscription?.cancel();

    await super.close();
  }
}
