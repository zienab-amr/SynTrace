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

  const ProjectsLoaded({
    required this.projects,
    this.searchQuery = '',
    this.selectedStatus,
    this.totalCount,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty || selectedStatus != null;

  @override
  List<Object?> get props => [
    projects,
    searchQuery,
    selectedStatus,
    totalCount,
  ];
}

class ProjectsError extends ProjectsState {
  final String message;

  const ProjectsError(this.message);

  @override
  List<Object?> get props => [message];
}
