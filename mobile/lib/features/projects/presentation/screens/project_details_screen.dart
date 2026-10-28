import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_info_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_stats_grid.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/section_title.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/team_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/project_overlays.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  ProjectModel? _project;
  ProjectStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  void _loadProject() {
    final project = MockProjects.projects.firstWhere(
      (p) => p.id == widget.projectId,
      orElse: () => MockProjects.projects.first,
    );

    setState(() {
      _project = project;
      _stats = MockProjectStats.forProject(project.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_project == null) {
      return const AppPageScaffold(
        title: 'Project',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final id = _project!.id;

    return AppPageScaffold(
      title: _project!.name,
      subtitle: _project!.description,
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Stats Grid ───
            if (_stats != null)
              ProjectStatsGrid(
                stats: _stats!,
                onHealthTap: () => ProjectOverlays.showHealth(context, id),
                onTasksTap: () => ProjectOverlays.showTasks(context, id),
                onBlockedTap: () => ProjectOverlays.showBlocked(context, id),
                onPRsTap: () => ProjectOverlays.showPRs(context, id),
                onCommitsTap: () => ProjectOverlays.showCommits(context, id),
              ),

            const SizedBox(height: 24),

            // ─── Team ───
            const SectionTitle(title: 'Team'),
            const SizedBox(height: 12),
            TeamSection(memberIds: _project!.memberIds),

            const SizedBox(height: 24),

            // ─── Details ───
            const SectionTitle(title: 'Details'),
            const SizedBox(height: 12),
            ProjectInfoSection(project: _project!),
          ],
        ),
      ),
    );
  }
}