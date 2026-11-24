import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/project_api_model.dart';
import '../../data/projects_repository.dart';

import 'projects_state.dart';

class ProjectsCubit extends Cubit<ProjectsState> {
  final ProjectsRepository _repository;

  ProjectsCubit({ProjectsRepository? repository})
    : _repository = repository ?? ProjectsRepository(),
      super(const ProjectsInitial());

  List<ProjectApiModel> _allProjects = [];

  String _searchQuery = '';

  CancelToken? _cancelToken;

  bool _isLoading = false;

  // ═══════════════════════════════════════════
  // Load Projects
  // ═══════════════════════════════════════════

  Future<void> loadProjects() async {
    if (isClosed || _isLoading) return;

    _isLoading = true;

    _cancelToken = CancelToken();

    emit(const ProjectsLoading());

    try {
      final projects = await _repository.getProjects(cancelToken: _cancelToken);

      if (isClosed) return;

      _allProjects = projects;

      _emitFiltered();
    } catch (error) {
      if (isClosed) return;

      if (error is DioException && CancelToken.isCancel(error)) {
        return;
      }

      _allProjects = [];

      emit(ProjectsError(_getErrorMessage(error)));
    } finally {
      _isLoading = false;
      _cancelToken = null;
    }
  }

  // ═══════════════════════════════════════════
  // Search
  // ═══════════════════════════════════════════

  void search(String query) {
    _searchQuery = query;

    if (state is ProjectsLoaded) {
      _emitFiltered();
    }
  }

  void clearFilters() {
    _searchQuery = '';

    if (state is ProjectsLoaded) {
      _emitFiltered();
    }
  }

  // ═══════════════════════════════════════════
  // Refresh
  // ═══════════════════════════════════════════

  Future<void> refresh() async {
    await loadProjects();
  }

  // ═══════════════════════════════════════════
  // Filter Projects
  // ═══════════════════════════════════════════

  void _emitFiltered() {
    if (isClosed) return;

    final query = _searchQuery.trim().toLowerCase();

    final filtered = _allProjects.where((project) {
      if (query.isEmpty) return true;

      final name = project.name.toLowerCase();

      final description = project.description?.toLowerCase() ?? '';

      return name.contains(query) || description.contains(query);
    }).toList();

    emit(
      ProjectsLoaded(
        projects: List.unmodifiable(filtered),
        searchQuery: _searchQuery,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Error Handling
  // ═══════════════════════════════════════════

  String _getErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;

      if (data is Map) {
        final message = data['message'];

        if (message is String && message.isNotEmpty) {
          return message;
        }
      }

      switch (error.response?.statusCode) {
        case 401:
          return 'Your session has expired.';

        case 403:
          return 'You do not have permission '
              'to access these projects.';

        case 503:
          return 'The service is temporarily '
              'unavailable.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'The request timed out. '
            'Please try again.';
      }
    }

    if (error is FormatException) {
      return 'Invalid project data received '
          'from the server.';
    }

    return 'Unable to load projects. '
        'Please try again.';
  }

  @override
  Future<void> close() {
    _cancelToken?.cancel();

    return super.close();
  }
}
