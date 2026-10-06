import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'package:syntrace/features/projects/presentation/widgets/project_card.dart';

class ProjectsGrid extends StatelessWidget {
  final List<ProjectModel> projects;
  final void Function(ProjectModel project)? onProjectTap;
  final Future<void> Function()? onRefresh;

  const ProjectsGrid({
    super.key,
    required this.projects,
    this.onProjectTap,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) return _buildEmptyState(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount;
        if (width < 600) {
          crossAxisCount = 1;
        } else if (width < 1024) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }

        if (crossAxisCount == 1) return _buildList(context);
        return _buildGrid(context, crossAxisCount);
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // List (Mobile)
  // ═══════════════════════════════════════════════════════
  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: projects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildProjectCard(projects[index]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Grid (Tablet + Desktop)
  // ═══════════════════════════════════════════════════════
  Widget _buildGrid(BuildContext context, int crossAxisCount) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surface,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 300,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) => _buildProjectCard(projects[index]),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    final stats = MockProjectStats.stats[project.id];
    final members = MockUsers.getByIds(project.memberIds);

    return ProjectCard(
      project: project,
      stats: stats,
      members: members,
      onTap: () => onProjectTap?.call(project),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first project to get started',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}