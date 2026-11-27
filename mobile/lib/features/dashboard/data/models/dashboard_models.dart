import 'package:equatable/equatable.dart';

import 'package:syntrace/features/projects/data/models/project_api_model.dart';

class DashboardData extends Equatable {
  final List<ProjectApiModel>? projects;
  final int? teamMembersCount;

  final String? projectsError;
  final String? teamError;

  const DashboardData({
    this.projects,
    this.teamMembersCount,
    this.projectsError,
    this.teamError,
  });

  int? get totalProjects => projects?.length;

  int? get activeProjects {
    final items = projects;

    if (items == null) return null;

    if (items.any(
      (project) =>
          project.status == null || project.status == ProjectApiStatus.unknown,
    )) {
      return null;
    }

    return items
        .where((project) => project.status == ProjectApiStatus.inProgress)
        .length;
  }

  int? get completedProjects {
    final items = projects;

    if (items == null) return null;

    if (items.any(
      (project) =>
          project.status == null || project.status == ProjectApiStatus.unknown,
    )) {
      return null;
    }

    return items
        .where((project) => project.status == ProjectApiStatus.completed)
        .length;
  }

  List<ProjectApiModel> get previewProjects =>
      List.unmodifiable(projects?.take(3) ?? const <ProjectApiModel>[]);

  bool get hasProjectsError => projectsError != null;

  bool get hasTeamError => teamError != null;

  @override
  List<Object?> get props => [
    projects,
    teamMembersCount,
    projectsError,
    teamError,
  ];
}
