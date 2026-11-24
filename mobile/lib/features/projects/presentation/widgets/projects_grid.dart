import 'package:flutter/material.dart';

import '../../data/models/project_api_model.dart';

import 'project_card.dart';

class ProjectsGrid extends StatelessWidget {
  final List<ProjectApiModel> projects;

  final void Function(ProjectApiModel project)? onProjectTap;

  final Future<void> Function()? onRefresh;

  const ProjectsGrid({
    super.key,
    required this.projects,
    this.onProjectTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.symmetric(vertical: 8),

      itemCount: projects.length,

      separatorBuilder: (context, index) {
        return const SizedBox(height: 12);
      },

      itemBuilder: (context, index) {
        final project = projects[index];

        return ProjectCard(
          key: ValueKey(project.id),

          project: project,

          onTap: () {
            onProjectTap?.call(project);
          },
        );
      },
    );

    if (onRefresh == null) {
      return list;
    }

    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
