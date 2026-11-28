import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../../data/models/project_api_model.dart';
import '../../data/models/github_activity_model.dart';

import '../cubit/details/project_details_cubit.dart';
import '../cubit/details/project_details_state.dart';

import '../widgets/details/project_details_tabs.dart';
import '../widgets/details/project_cache_indicator.dart';
import '../widgets/details/members/project_members_section.dart';

import '../widgets/details/overview/project_overview.dart';
import '../widgets/details/overview/project_unavailable_tab.dart';
import '../widgets/details/overview/project_details_error.dart';

import '../widgets/details/project_team_notes_section.dart';
import '../widgets/details/project_ai_notes_section.dart';

import '../widgets/github/project_github_integration_section.dart';
import '../widgets/github/activity/github_activity_section.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null ||
            user.id.isEmpty ||
            user.tenantId?.isNotEmpty != true) {
          return const AppPageScaffold(
            title: 'Project',
            showBackButton: true,
            child: Center(child: Text('Your session is unavailable.')),
          );
        }

        return BlocProvider(
          key: ValueKey(
            '${user.tenantId}-${user.id}-'
            '${user.role}-$projectId',
          ),
          create: (_) =>
              ProjectDetailsCubit(projectId: projectId)..loadProject(),
          child: const _ProjectDetailsView(),
        );
      },
    );
  }
}

class _ProjectDetailsView extends StatefulWidget {
  const _ProjectDetailsView();

  @override
  State<_ProjectDetailsView> createState() => _ProjectDetailsViewState();
}

class _ProjectDetailsViewState extends State<_ProjectDetailsView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 7, vsync: this);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<ProjectDetailsCubit>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectDetailsCubit, ProjectDetailsState>(
      builder: (context, state) {
        final cubit = context.read<ProjectDetailsCubit>();

        final project = state.project;

        if (state.isLoading && project == null) {
          return const AppPageScaffold(
            title: 'Project',
            showBackButton: true,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (project == null) {
          return AppPageScaffold(
            title: 'Project',
            showBackButton: true,
            child: ProjectDetailsError(
              message: state.errorMessage,
              onRetry: cubit.refresh,
            ),
          );
        }

        return AppPageScaffold(
          title: project.name,
          subtitle: project.description,
          showBackButton: true,
          scrollable: false,
          actions: [
            IconButton(
              tooltip: 'Refresh project',
              onPressed: state.isRefreshing ? null : cubit.refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isFromCache || state.isRefreshing)
                ProjectCacheIndicator(isRefreshing: state.isRefreshing),

              ProjectDetailsTabs(controller: _tabController),

              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProjectOverview(
                      project: project,
                      githubIntegration: _buildGitHubIntegration(project),
                      teamSection: _buildProjectMembers(project),
                    ),

                    const ProjectUnavailableTab(
                      icon: Icons.task_alt_rounded,
                      title: 'Tasks unavailable',
                      message:
                          'Project tasks are not available '
                          'in the mobile app yet.',
                    ),

                    GitHubActivitySection(
                      key: ValueKey('${project.id}-pull-requests'),
                      projectId: project.id,
                      kind: GitHubActivityKind.pullRequest,
                    ),

                    GitHubActivitySection(
                      key: ValueKey('${project.id}-commits'),
                      projectId: project.id,
                      kind: GitHubActivityKind.commit,
                    ),

                    const ProjectUnavailableTab(
                      icon: Icons.bug_report_outlined,
                      title: 'Bugs unavailable',
                      message:
                          'Project bug data is not available '
                          'in the mobile app yet.',
                    ),

                    _buildConstrainedContent(
                      ProjectTeamNotesSection(projectId: project.id),
                    ),

                    _buildConstrainedContent(
                      ProjectAiNotesSection(projectId: project.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGitHubIntegration(ProjectApiModel project) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null || project.id.isEmpty) {
          return const SizedBox.shrink();
        }

        return ProjectGitHubIntegrationSection(
          key: ValueKey('${user.id}-${user.tenantId}-${project.id}'),
          projectId: project.id,
          canManage: user.isAdmin,
        );
      },
    );
  }

  Widget _buildProjectMembers(ProjectApiModel project) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null ||
            user.id.isEmpty ||
            user.tenantId?.isNotEmpty != true) {
          return const SizedBox.shrink();
        }

        return ProjectMembersSection(
          key: ValueKey(
            '${user.tenantId}-${user.id}-'
            '${user.role}-${project.id}',
          ),
          projectId: project.id,
        );
      },
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
}
