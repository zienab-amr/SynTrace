import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_entry.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/sync/services/connectivity_service.dart';

import '../../../data/models/project_api_model.dart';
import '../../../data/services/project_details_sync_service.dart';

import 'project_details_state.dart';

class ProjectDetailsCubit extends Cubit<ProjectDetailsState> {
  final String projectId;

  final _service = ProjectDetailsSyncService.instance;
  final _session = CurrentUserService.instance;
  final _connectivity = ConnectivityService();

  CacheSessionGuard? _guard;
  CancelToken? _cancelToken;

  StreamSubscription<bool>? _connectionSubscription;

  Timer? _expiryTimer;
  Timer? _refreshTimer;

  bool _running = false;

  ProjectDetailsCubit({required this.projectId})
    : super(const ProjectDetailsState()) {
    _session.userNotifier.addListener(_onSessionChanged);

    _connectionSubscription = _connectivity.connectionChanges.listen((
      connected,
    ) {
      if (connected && !isClosed) {
        unawaited(loadProject());
      }
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!isClosed) {
        unawaited(loadProject());
      }
    });
  }

  bool _canPublish(CacheSessionGuard guard, CancelToken token) {
    return !isClosed &&
        identical(_guard, guard) &&
        identical(_cancelToken, token) &&
        guard.isValid &&
        !token.isCancelled;
  }

  void _onSessionChanged() {
    if (_guard?.isValid == true) return;

    _cancelToken?.cancel();
    _expiryTimer?.cancel();

    _guard = null;
    _running = false;

    if (!isClosed) {
      emit(const ProjectDetailsState());
    }
  }

  Future<void> loadProject() async {
    if (isClosed || _running) return;

    final scope = CacheScope.fromCurrentUser();

    if (scope == null) {
      emit(
        const ProjectDetailsState(errorMessage: 'Your session is unavailable.'),
      );
      return;
    }

    late final CacheSessionGuard guard;

    try {
      guard = CacheSessionGuard.capture(scope);
    } catch (_) {
      emit(
        const ProjectDetailsState(errorMessage: 'Your session is unavailable.'),
      );
      return;
    }

    _guard = guard;

    final token = CancelToken();
    _cancelToken = token;

    _running = true;

    emit(
      ProjectDetailsState(
        project: state.project,
        isLoading: !state.hasData,
        isRefreshing: state.hasData,
        isFromCache: state.isFromCache,
        lastSyncedAt: state.lastSyncedAt,
      ),
    );

    CacheEntry<ProjectApiModel>? cached;

    try {
      cached = await _service.local.readProjectDetails(
        scope: scope,
        projectId: projectId,
      );

      if (!_canPublish(guard, token)) return;

      if (cached != null) {
        _showCache(cached, guard, isRefreshing: true);
      }

      final connected = await _connectivity.hasNetworkConnection();

      if (!_canPublish(guard, token)) return;

      if (!connected) {
        if (cached != null && !cached.isExpired) {
          _showCache(cached, guard, message: 'Showing saved project details.');
        } else {
          emit(
            const ProjectDetailsState(
              errorMessage: 'Connect to load this project for the first time.',
            ),
          );
        }

        return;
      }

      final project = await _service.refresh(
        scope: scope,
        projectId: projectId,
        cancelToken: token,
      );

      if (!_canPublish(guard, token)) return;

      final saved = await _service.local.readProjectDetails(
        scope: scope,
        projectId: projectId,
      );

      if (!_canPublish(guard, token)) return;

      _scheduleExpiry(guard, saved?.expiresAt);

      emit(
        ProjectDetailsState(
          project: project,
          lastSyncedAt: saved?.syncedAt ?? DateTime.now().toUtc(),
        ),
      );
    } catch (error) {
      if (!_canPublish(guard, token)) return;

      if (_canUseCache(error) && cached != null && !cached.isExpired) {
        _showCache(
          cached,
          guard,
          message: 'Unable to sync. Showing saved details.',
        );
      } else {
        _expiryTimer?.cancel();

        emit(ProjectDetailsState(errorMessage: _getErrorMessage(error)));
      }
    } finally {
      if (identical(_cancelToken, token)) {
        _running = false;
      }
    }
  }

  void _showCache(
    CacheEntry<ProjectApiModel> entry,
    CacheSessionGuard guard, {
    bool isRefreshing = false,
    String? message,
  }) {
    if (isClosed || !guard.isValid || entry.isExpired) {
      return;
    }

    _scheduleExpiry(guard, entry.expiresAt);

    emit(
      ProjectDetailsState(
        project: entry.data,
        isFromCache: true,
        isRefreshing: isRefreshing,
        lastSyncedAt: entry.syncedAt,
        errorMessage: message,
      ),
    );
  }

  void _scheduleExpiry(CacheSessionGuard guard, DateTime? expiresAt) {
    _expiryTimer?.cancel();

    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now().toUtc());

    _expiryTimer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (isClosed || !guard.isValid || !identical(_guard, guard)) {
        return;
      }

      emit(
        const ProjectDetailsState(
          errorMessage:
              'Saved project details have expired. '
              'Connect to refresh.',
        ),
      );
    });
  }

  bool _canUseCache(Object error) {
    if (error is! DioException) return false;

    final status = error.response?.statusCode;

    if (status == 502 || status == 503 || status == 504 || status == 500) {
      return true;
    }

    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
          return 'Your session has expired.';
        case 403:
          return 'You do not have access to this project.';
        case 404:
          return 'Project not found or unavailable.';
        case 503:
          return 'The server is temporarily unavailable.';
      }
    }

    if (error is FormatException) {
      return 'Invalid project data received.';
    }

    return 'Unable to load project details.';
  }

  Future<void> refresh() => loadProject();

  @override
  Future<void> close() async {
    _session.userNotifier.removeListener(_onSessionChanged);

    _guard = null;

    _cancelToken?.cancel();
    _expiryTimer?.cancel();
    _refreshTimer?.cancel();

    await _connectionSubscription?.cancel();

    await super.close();
  }
}
