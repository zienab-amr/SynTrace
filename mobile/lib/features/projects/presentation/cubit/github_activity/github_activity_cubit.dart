import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/github_activity_repository.dart';
import '../../../data/models/github_activity_model.dart';

import 'github_activity_state.dart';

class GitHubActivityCubit extends Cubit<GitHubActivityState> {
  final GitHubActivityRepository _repository;

  final String projectId;
  final GitHubActivityKind kind;

  CancelToken? _cancelToken;

  GitHubActivityCubit({
    required this.projectId,
    required this.kind,
    GitHubActivityRepository? repository,
  }) : _repository = repository ?? GitHubActivityRepository(),
       super(const GitHubActivityState());

  // Initial Loading

  Future<void> loadActivity() async {
    if (isClosed) return;

    final token = _createRequest();

    emit(const GitHubActivityState(status: GitHubActivityStatus.loading));

    await _fetchFirstPage(token);
  }

  // Refresh

  Future<void> refresh() async {
    if (isClosed) return;

    if (state.status != GitHubActivityStatus.success) {
      await loadActivity();
      return;
    }

    final token = _createRequest();

    emit(
      state.copyWith(
        isRefreshing: true,
        isLoadingMore: false,
        clearError: true,
        clearPaginationError: true,
      ),
    );

    await _fetchFirstPage(token);
  }

  // Fetch First Page

  Future<void> _fetchFirstPage(CancelToken token) async {
    try {
      final page = await _repository.getActivity(
        projectId: projectId,
        kind: kind,
        offset: 0,
        cancelToken: token,
      );

      if (!_isCurrentRequest(token)) return;

      final ids = <String>{};
      final items = page.items.where((item) => ids.add(item.id));
      emit(
        GitHubActivityState(
          status: GitHubActivityStatus.success,
          items: List.unmodifiable(items),
          source: page.source,
          nextOffset: (page.nextOffset ?? 0) > 0 ? page.nextOffset : null,
        ),
      );
    } catch (error) {
      if (!_isCurrentRequest(token)) return;

      _handleError(error);
    }
  }

  // Pagination

  Future<void> loadMore() async {
    if (isClosed || !state.canLoadMore) return;

    final offset = state.nextOffset;
    final previousSource = state.source;

    if (offset == null || previousSource == null) {
      return;
    }

    final token = _createRequest();

    emit(state.copyWith(isLoadingMore: true, clearPaginationError: true));

    try {
      final page = await _repository.getActivity(
        projectId: projectId,
        kind: kind,
        offset: offset,
        cancelToken: token,
      );

      if (!_isCurrentRequest(token)) return;

      final sourceChanged =
          previousSource.bindingId != page.source.bindingId ||
          previousSource.repositoryId != page.source.repositoryId ||
          previousSource.completedVersion != page.source.completedVersion;

      if (sourceChanged) {
        await loadActivity();
        return;
      }

      final existingIds = state.items.map((item) => item.id).toSet();

      final newItems = page.items
          .where((item) => existingIds.add(item.id))
          .toList();

      final nextOffset = page.nextOffset;
      final hasNext = nextOffset != null && nextOffset > offset;
      emit(
        state.copyWith(
          status: GitHubActivityStatus.success,
          items: List.unmodifiable([...state.items, ...newItems]),
          source: page.source,
          nextOffset: hasNext ? nextOffset : null,
          clearNextOffset: !hasNext,
          isLoadingMore: false,
          clearPaginationError: true,
        ),
      );
    } catch (error) {
      if (!_isCurrentRequest(token)) return;

      _handleError(error, isPagination: true);
    }
  }

  // Retry

  Future<void> retry() async {
    if (isClosed) return;

    if (state.paginationError != null && state.hasMore) {
      await loadMore();
      return;
    }

    await loadActivity();
  }

  // Clear Activity

  void clearActivity() {
    if (isClosed) return;

    _cancelToken?.cancel();
    _cancelToken = null;

    emit(const GitHubActivityState());
  }

  // Request Management

  CancelToken _createRequest() {
    _cancelToken?.cancel();

    final token = CancelToken();

    _cancelToken = token;

    return token;
  }

  bool _isCurrentRequest(CancelToken token) {
    return !isClosed && !token.isCancelled && identical(_cancelToken, token);
  }

  // Error Handling

  void _handleError(Object error, {bool isPagination = false}) {
    if (isClosed) return;

    if (error is DioException && CancelToken.isCancel(error)) {
      return;
    }

    final statusCode = error is DioException
        ? error.response?.statusCode
        : null;

    final message = _getErrorMessage(error);

    // Clear sensitive data when access is lost.

    if (statusCode == 401 || statusCode == 403) {
      emit(
        GitHubActivityState(
          status: GitHubActivityStatus.forbidden,
          errorMessage: message,
        ),
      );

      return;
    }

    // Project or repository is unavailable.

    if (statusCode == 404) {
      emit(
        GitHubActivityState(
          status: GitHubActivityStatus.unavailable,
          errorMessage: message,
        ),
      );

      return;
    }

    // Keep previously loaded data on pagination errors.

    if (isPagination) {
      emit(state.copyWith(isLoadingMore: false, paginationError: message));

      return;
    }

    // Clear old data if refresh cannot verify access.

    emit(
      GitHubActivityState(
        status: GitHubActivityStatus.failure,
        errorMessage: message,
      ),
    );
  }

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 400:
          return 'Invalid GitHub activity request.';

        case 401:
          return 'Your session has expired.';

        case 403:
          return 'You do not have permission to '
              'view this GitHub activity.';

        case 404:
          return 'This project or its GitHub '
              'repository is unavailable.';

        case 409:
          return 'The GitHub repository is not '
              'currently available.';

        case 429:
          return 'Too many requests. '
              'Please try again later.';

        case 503:
          return 'The GitHub service is '
              'temporarily unavailable.';
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'The request timed out. '
              'Please try again.';

        case DioExceptionType.connectionError:
          return 'Unable to connect to the server.';

        default:
          break;
      }
    }

    if (error is FormatException || error is TypeError) {
      return 'Invalid GitHub activity data '
          'received from the server.';
    }

    return 'Unable to load GitHub activity. '
        'Please try again.';
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel();
    _cancelToken = null;

    return super.close();
  }
}
