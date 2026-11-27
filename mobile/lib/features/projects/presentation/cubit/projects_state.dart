import 'package:syntrace/core/state/base_state.dart';

import '../../data/models/project_api_model.dart';

abstract class ProjectsState extends BaseState {
  const ProjectsState();
}

class ProjectsInitial extends ProjectsState {
  const ProjectsInitial();
}

class ProjectsLoading extends ProjectsState {
  const ProjectsLoading();
}

class ProjectsLoaded extends ProjectsState {
  final List<ProjectApiModel> projects;
  final String searchQuery;
  final ProjectApiStatus? selectedStatus;
  final int? totalCount;

  final bool isRefreshing;
  final bool isFromCache;
  final bool isStale;

  final DateTime? lastSyncedAt;
  final String? syncError;

  const ProjectsLoaded({
    required this.projects,
    this.searchQuery = '',
    this.selectedStatus,
    this.totalCount,
    this.isRefreshing = false,
    this.isFromCache = false,
    this.isStale = false,
    this.lastSyncedAt,
    this.syncError,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty || selectedStatus != null;

  @override
  List<Object?> get props => [
    projects,
    searchQuery,
    selectedStatus,
    totalCount,
    isRefreshing,
    isFromCache,
    isStale,
    lastSyncedAt,
    syncError,
  ];
}

class ProjectsError extends ProjectsState {
  final String message;

  const ProjectsError(this.message);

  @override
  List<Object?> get props => [message];
}
