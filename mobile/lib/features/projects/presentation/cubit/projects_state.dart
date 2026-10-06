import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/core/state/base_state.dart';

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
  final List<ProjectModel> projects;
  final String searchQuery;
  final ProjectStatus? statusFilter;
  final String? riskFilter;

  const ProjectsLoaded({
    required this.projects,
    this.searchQuery = '',
    this.statusFilter,
    this.riskFilter,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      statusFilter != null ||
      riskFilter != null;

  ProjectsLoaded copyWith({
    List<ProjectModel>? projects,
    String? searchQuery,
    ProjectStatus? statusFilter,
    String? riskFilter,
    bool clearStatus = false,
    bool clearRisk = false,
  }) {
    return ProjectsLoaded(
      projects: projects ?? this.projects,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      riskFilter: clearRisk ? null : (riskFilter ?? this.riskFilter),
    );
  }

  @override
  List<Object?> get props => [
        projects,
        searchQuery,
        statusFilter,
        riskFilter,
      ];
}

class ProjectsError extends ProjectsState {
  final String message;
  const ProjectsError(this.message);

  @override
  List<Object?> get props => [message];
}