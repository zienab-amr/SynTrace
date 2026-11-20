import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_ai_notes_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_info_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_notes_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_stats_grid.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_team_notes_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/team_section.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/bugs_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/commits_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/prs_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/overlays/tasks_list_view.dart';
import 'package:syntrace/features/projects/presentation/widgets/details/project_details_tabs.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  ProjectModel? _project;
  ProjectStats? _stats;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // 6 تابات
    _loadProject();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    return AppPageScaffold(
      title: _project!.name,
      subtitle: _project!.description,
      showBackButton: true,
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.settings,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProjectDetailsTabs(controller: _tabController),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildConstrainedContent(
                  TasksListView(projectId: _project!.id),
                ),
                _buildConstrainedContent(PRsListView(projectId: _project!.id)),
                _buildConstrainedContent(
                  CommitsListView(projectId: _project!.id),
                ),
                _buildConstrainedContent(const BugsListView()),
                _buildConstrainedContent(
                  ProjectTeamNotesSection(projectId: _project!.id),
                ),
                _buildConstrainedContent(const ProjectAiNotesSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstrainedContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: child,
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_stats != null)
            ProjectStatsGrid(
              stats: _stats!,
              onHealthTap: () {},
              onTasksTap: () => _tabController.animateTo(1),
              onBlockedTap: () => _tabController.animateTo(4),
              onPRsTap: () => _tabController.animateTo(2),
              onCommitsTap: () => _tabController.animateTo(3),
            ),

          const SizedBox(height: 32),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 800;

              final teamWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team Members',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TeamSection(memberIds: _project!.memberIds),
                ],
              );

              final infoWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Project Information',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ProjectInfoSection(project: _project!),
                ],
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: teamWidget),
                    const SizedBox(width: 24),
                    Expanded(child: infoWidget),
                  ],
                );
              }

              return Column(
                children: [teamWidget, const SizedBox(height: 24), infoWidget],
              );
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
