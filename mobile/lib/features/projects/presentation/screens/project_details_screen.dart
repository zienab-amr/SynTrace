import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';

import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

import '../../data/models/project_api_model.dart';
import '../../data/projects_repository.dart';

import '../widgets/details/project_details_tabs.dart';
import '../widgets/details/overview/project_overview.dart';
import '../widgets/details/overview/project_unavailable_tab.dart';
import '../widgets/details/overview/project_details_error.dart';
import '../widgets/details/project_team_notes_section.dart';
import '../widgets/details/project_ai_notes_section.dart';

import '../widgets/github/project_github_integration_section.dart';
import '../../data/models/github_activity_model.dart';
import '../widgets/github/activity/github_activity_section.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  final ProjectsRepository _repository = ProjectsRepository();

  late final TabController _tabController;

  ProjectApiModel? _project;

  CancelToken? _cancelToken;

  bool _isLoading = true;

  String? _errorMessage;

  // ═══════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 7, vsync: this);

    _loadProject();
  }

  @override
  void didUpdateWidget(covariant ProjectDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      _tabController.index = 0;

      _loadProject();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();

    _tabController.dispose();

    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Load Real Project
  // ═══════════════════════════════════════════

  Future<void> _loadProject() async {
    _cancelToken?.cancel();

    final token = CancelToken();

    _cancelToken = token;

    final projectId = widget.projectId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _project = null;
    });

    try {
      final project = await _repository.getProjectById(
        projectId,
        cancelToken: token,
      );

      if (!mounted || token.isCancelled || _cancelToken != token) {
        return;
      }

      setState(() {
        _project = project;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || token.isCancelled || _cancelToken != token) {
        return;
      }

      setState(() {
        _project = null;
        _isLoading = false;
        _errorMessage = _getErrorMessage(error);
      });
    }
  }

  // ═══════════════════════════════════════════
  // Main Screen
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppPageScaffold(
        title: 'Project',
        showBackButton: true,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final project = _project;

    if (_errorMessage != null || project == null) {
      return AppPageScaffold(
        title: 'Project',
        showBackButton: true,
        child: ProjectDetailsError(message: _errorMessage, onRetry: _loadProject),
      );
    }

    return AppPageScaffold(
      title: project.name,

      subtitle: project.description,

      showBackButton: true,

      actions: [
        IconButton(
          tooltip: 'Refresh project',
          onPressed: _loadProject,
          icon: const Icon(Icons.refresh_rounded),
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
                // Overview
                ProjectOverview(project: project, githubIntegration: _buildGitHubIntegration(project)),

                // Tasks
                const ProjectUnavailableTab(
                  icon: Icons.task_alt_rounded,
                  title: 'Tasks unavailable',
                  message:
                      'Project tasks are not available '
                      'in the mobile app yet.',
                ),

                // Pull Requests
                GitHubActivitySection(
                  key: ValueKey('${project.id}-pull-requests'),
                  projectId: project.id,
                  kind: GitHubActivityKind.pullRequest,
                ),

                // Commits
                GitHubActivitySection(
                  key: ValueKey('${project.id}-commits'),
                  projectId: project.id,
                  kind: GitHubActivityKind.commit,
                ),

                // Bugs
                const ProjectUnavailableTab(
                  icon: Icons.bug_report_outlined,
                  title: 'Bugs unavailable',
                  message:
                      'Project bug data is not available '
                      'in the mobile app yet.',
                ),

                // Team Notes
                _buildConstrainedContent(
                  ProjectTeamNotesSection(projectId: project.id),
                ),

                // AI Notes
                _buildConstrainedContent(
                  ProjectAiNotesSection(projectId: project.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // GitHub Integration
  // ═══════════════════════════════════════════

  Widget _buildGitHubIntegration(ProjectApiModel project) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,

      builder: (context, user, _) {
        if (user == null ||
            project.id.isEmpty ||
            project.id != widget.projectId) {
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

  Widget _buildConstrainedContent(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: child,
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
              'to access this project.';

        case 404:
          return 'Project not found or unavailable.';

        case 503:
          return 'The service is temporarily '
              'unavailable.';
      }
    }

    if (error is FormatException) {
      return 'Invalid project data received '
          'from the server.';
    }

    return 'Unable to load project details. '
        'Please try again.';
  }
}
