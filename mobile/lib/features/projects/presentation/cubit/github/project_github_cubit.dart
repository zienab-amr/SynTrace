import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/features/settings/data/integrations_repository.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

import 'project_github_state.dart';

class ProjectGitHubCubit extends Cubit<ProjectGitHubState> {
  final IntegrationsRepository _repository;

  final String projectId;
  final bool canManage;

  Timer? _pollingTimer;

  bool _isFetching = false;
  bool _isActive = true;

  static const Duration _pollingInterval = Duration(seconds: 5);

  ProjectGitHubCubit({
    required this.projectId,
    required this.canManage,
    IntegrationsRepository? repository,
  }) : _repository = repository ?? IntegrationsRepository(),
       super(const ProjectGitHubState());

  // ═══════════════════════════════════════════
  // Load Project Integration
  // ═══════════════════════════════════════════

  Future<void> loadIntegration() async {
    await _fetchIntegration();
  }

  Future<void> refreshIntegration() async {
    await _fetchIntegration(refresh: true);
  }

  Future<void> _fetchIntegration({
    bool refresh = false,
    bool silent = false,
    bool afterAction = false,
  }) async {
    if (isClosed ||
        (!_isActive && !afterAction) ||
        _isFetching ||
        (state.isBusy && !afterAction)) {
      return;
    }

    _isFetching = true;

    if (!silent) {
      emit(
        state.copyWith(
          status: state.integration == null
              ? ProjectGitHubRequestStatus.loading
              : state.status,
          isRefreshing: refresh,
          clearError: true,
        ),
      );
    }

    try {
      final response = await _repository.getGitHubProjectStatus(projectId);

      _ensureSuccess(response);

      final integration = GitHubProjectStatus.fromJson(_asMap(response.data));

      if (isClosed) return;

      final bindingChanged =
          state.integration?.bindingId != integration.bindingId;

      emit(
        state.copyWith(
          status: ProjectGitHubRequestStatus.success,
          integration: integration,
          clearCoverage:
              bindingChanged ||
              !integration.isMapped ||
              integration.isUnavailable,
          clearError: true,
        ),
      );

      if (integration.isMapped && !integration.isUnavailable) {
        await _fetchCoverage();
      } else {
        if (!isClosed) {
          emit(state.copyWith(clearCoverage: true, clearCoverageError: true));
        }
      }
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copyWith(
          status: ProjectGitHubRequestStatus.failure,
          errorMessage: _getErrorMessage(error),
        ),
      );

      if (error is DioException) {
        final code = error.response?.statusCode;

        if (code == 401 || code == 403 || code == 404) {
          stopPolling();

          _clearRestrictedData();
        }
      }
    } finally {
      _isFetching = false;

      if (!isClosed) {
        emit(state.copyWith(isRefreshing: false));

        _updatePolling();
      }
    }
  }

  // ═══════════════════════════════════════════
  // Fetch Sync Coverage
  // ═══════════════════════════════════════════

  Future<void> _fetchCoverage() async {
    try {
      final response = await _repository.getGitHubProjectActivity(
        projectId,
        kind: 'commit',
        offset: 0,
      );

      _ensureSuccess(response);

      final data = _asMap(response.data);

      final coverage = GitHubSyncCoverage.fromJson(_asMap(data['source']));

      if (isClosed) return;

      if (coverage.bindingId != state.integration?.bindingId) {
        emit(
          state.copyWith(
            clearCoverage: true,
            coverageError: 'Repository binding changed. Refresh again.',
          ),
        );

        return;
      }

      emit(state.copyWith(coverage: coverage, clearCoverageError: true));
    } catch (error) {
      if (isClosed) return;
      if (_isAccessLost(error)) {
        _clearRestrictedData();
        emit(state.copyWith(errorMessage: _getErrorMessage(error)));
        return;
      }

      emit(
        state.copyWith(
          clearCoverage: true,
          coverageError: _getErrorMessage(error),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════
  // Load Available Repositories
  // ═══════════════════════════════════════════

  Future<void> loadRepositories() async {
    if (isClosed || !_isActive || !canManage || state.isLoadingRepositories || state.isBusy) {
      return;
    }

    emit(
      state.copyWith(
        repositoriesStatus: ProjectGitHubRequestStatus.loading,
        clearRepositoriesError: true,
      ),
    );

    try {
      final response = await _repository.getGitHubRepositories();

      _ensureSuccess(response);

      final data = response.data;

      if (data is! List) {
        throw const FormatException('Invalid repositories response.');
      }

      final repositories = data
          .map((item) => GitHubRepositoryOption.fromJson(_asMap(item)))
          .toList();

      repositories.sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

      if (isClosed || !state.isLoadingRepositories) return;

      emit(
        state.copyWith(
          repositoriesStatus: ProjectGitHubRequestStatus.success,
          repositories: List.unmodifiable(repositories),
          clearRepositoriesError: true,
        ),
      );
    } catch (error) {
      if (isClosed || !state.isLoadingRepositories) return;

      emit(
        state.copyWith(
          repositoriesStatus: ProjectGitHubRequestStatus.failure,
          repositoriesError: _getErrorMessage(error),
          repositories: const [],
        ),
      );
    }
  }

  // ═══════════════════════════════════════════
  // Link Repository
  // ═══════════════════════════════════════════

  Future<bool> linkRepository(int repositoryId) async {
    if (isClosed ||
        !canManage ||
        !state.canSelectRepository ||
        repositoryId <= 0) {
      return false;
    }

    return _runAction(
      action: ProjectGitHubAction.linking,
      request: () {
        return _repository.mapGitHubRepository(
          projectId: projectId,
          repositoryId: repositoryId,
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // Resync / Retry
  // ═══════════════════════════════════════════

  Future<bool> requestSync() async {
    if (isClosed || !canManage || !state.canRequestSync) {
      return false;
    }

    return _runAction(
      action: ProjectGitHubAction.syncing,
      request: () {
        return _repository.requestGitHubProjectSync(projectId);
      },
    );
  }

  // ═══════════════════════════════════════════
  // Unlink Repository
  // ═══════════════════════════════════════════

  Future<bool> unlinkRepository() async {
    if (isClosed || !canManage || !state.canUnlink) {
      return false;
    }

    return _runAction(
      action: ProjectGitHubAction.unlinking,
      request: () {
        return _repository.unmapGitHubRepository(projectId);
      },
    );
  }

  // ═══════════════════════════════════════════
  // Shared Mutation Handler
  // ═══════════════════════════════════════════

  Future<bool> _runAction({
    required ProjectGitHubAction action,
    required Future<Response> Function() request,
  }) async {
    if (isClosed || !_isActive || !canManage || state.isBusy || _isFetching) {
      return false;
    }

    stopPolling();

    emit(state.copyWith(action: action, clearError: true));

    try {
      final response = await request();

      _ensureSuccess(response);

      if (isClosed) return false;

      // Invalidate stale data after a successful mutation.
      emit(
        state.copyWith(
          clearIntegration: true,
          clearCoverage: true,
          clearCoverageError: true,
          status: ProjectGitHubRequestStatus.loading,
        ),
      );

      // Always reload the authoritative server state.
      await _fetchIntegration(silent: true, afterAction: true);

      // True means the mutation was accepted,
      // not that synchronization has completed.
      return true;
    } catch (error) {
      if (isClosed) return false;

      if (_isAccessLost(error)) {
        _clearRestrictedData();
      }
      emit(state.copyWith(errorMessage: _getErrorMessage(error)));

      return false;
    } finally {
      if (!isClosed) {
        emit(state.copyWith(action: ProjectGitHubAction.none));

        _updatePolling();
      }
    }
  }

  // ═══════════════════════════════════════════
  // Automatic Polling
  // ═══════════════════════════════════════════

  void _updatePolling() {
    if (isClosed || !_isActive || state.isBusy || !state.isProcessing) {
      stopPolling();
      return;
    }

    if (_pollingTimer?.isActive ?? false) {
      return;
    }

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (isClosed || !_isActive || _isFetching || state.isBusy) {
        return;
      }

      unawaited(_fetchIntegration(silent: true));
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ═══════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════

  void pausePolling() {
    _isActive = false;
    stopPolling();
  }

  Future<void> resumePolling() async {
    if (isClosed) return;

    _isActive = true;

    await _fetchIntegration(silent: true);

    _updatePolling();
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  bool _isAccessLost(Object error) =>
      error is DioException &&
      const [401, 403, 404].contains(error.response?.statusCode);

  void _clearRestrictedData() {
    stopPolling();
    emit(state.copyWith(
      status: ProjectGitHubRequestStatus.failure,
      clearIntegration: true,
      clearCoverage: true,
      clearCoverageError: true,
      repositories: const [],
      repositoriesStatus: ProjectGitHubRequestStatus.initial,
      clearRepositoriesError: true,
    ));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw const FormatException('Invalid GitHub response.');
  }

  void _ensureSuccess(Response response) {
    final code = response.statusCode;

    if (code == null || code < 200 || code >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      final data = error.response?.data;

      if (data is Map) {
        final message = data['message'] ?? data['detail'];

        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }

      switch (code) {
        case 400:
          return 'Invalid GitHub integration request.';

        case 401:
          return 'Your session has expired.';

        case 403:
          return 'You do not have permission '
              'to perform this action.';

        case 404:
          return 'Project or repository integration '
              'was not found.';

        case 409:
          return 'Repository integration conflict.';

        case 429:
          return 'Too many requests. Try again later.';

        case 503:
          return 'GitHub integration is currently '
              'unavailable.';

        default:
          return 'Unable to complete the GitHub request.';
      }
    }

    if (error is FormatException) {
      return 'The server returned an unexpected response.';
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() {
    _isActive = false;
    stopPolling();

    return super.close();
  }
}
