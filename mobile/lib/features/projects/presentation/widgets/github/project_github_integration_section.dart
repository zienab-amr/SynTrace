import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';

import '../../cubit/github/project_github_cubit.dart';
import '../../cubit/github/project_github_state.dart';

import 'github_repository_picker.dart';
import 'github_sync_coverage_section.dart';
import 'integration/github_confirmation_dialog.dart';
import 'integration/github_integration_error.dart';
import 'integration/github_management_actions.dart';
import 'integration/github_unlinked_repository.dart';
import 'integration/github_linked_repository_card.dart';
import 'integration/github_integration_header.dart';

class ProjectGitHubIntegrationSection extends StatelessWidget {
  final String projectId;
  final bool canManage;

  const ProjectGitHubIntegrationSection({
    super.key,
    required this.projectId,
    required this.canManage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: ValueKey('$projectId-$canManage'),
      create: (_) =>
          ProjectGitHubCubit(projectId: projectId, canManage: canManage)
            ..loadIntegration(),
      child: const _ProjectGitHubIntegrationView(),
    );
  }
}

class _ProjectGitHubIntegrationView extends StatefulWidget {
  const _ProjectGitHubIntegrationView();

  @override
  State<_ProjectGitHubIntegrationView> createState() =>
      _ProjectGitHubIntegrationViewState();
}

class _ProjectGitHubIntegrationViewState
    extends State<_ProjectGitHubIntegrationView>
    with WidgetsBindingObserver {
  late final ProjectGitHubCubit _cubit;

  @override
  void initState() {
    super.initState();

    _cubit = context.read<ProjectGitHubCubit>();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cubit.isClosed) return;

    if (state == AppLifecycleState.resumed) {
      _cubit.resumePolling();
    } else {
      _cubit.pausePolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cubit.stopPolling();

    super.dispose();
  }

  // ═══════════════════════════════════════════
  // Link Repository
  // ═══════════════════════════════════════════

  Future<void> _selectRepository() async {
    final repository = await GitHubRepositoryPicker.show(context);

    if (!mounted || repository == null) return;

    final confirmed = await showGitHubConfirmation(context,
      title: 'Link Repository',
      message:
          'Connect "${repository.fullName}" '
          'to this project?\n\n'
          'Repository synchronization will be '
          'requested automatically.',
      confirmLabel: 'Link Repository',
    );

    if (!mounted || !confirmed) return;

    final success = await _cubit.linkRepository(repository.repositoryId);

    if (!mounted) return;

    _showActionResult(
      success: success,
      successMessage: 'Repository linked. Synchronization requested.',
      failureMessage: 'Unable to link repository.',
    );
  }

  // ═══════════════════════════════════════════
  // Resync / Retry
  // ═══════════════════════════════════════════

  Future<void> _requestSync() async {
    final isRetry =
        _cubit.state.integration?.syncStatus == GitHubSyncStatus.retrying;

    final confirmed = await showGitHubConfirmation(context,
      title: isRetry ? 'Retry Synchronization' : 'Resync Repository',
      message:
          'Request a new synchronization '
          'for this repository?',
      confirmLabel: isRetry ? 'Retry' : 'Resync',
    );

    if (!mounted || !confirmed) return;

    final success = await _cubit.requestSync();

    if (!mounted) return;

    _showActionResult(
      success: success,
      successMessage: 'Synchronization requested.',
      failureMessage: 'Unable to request synchronization.',
    );
  }

  // ═══════════════════════════════════════════
  // Unlink Repository
  // ═══════════════════════════════════════════

  Future<void> _unlinkRepository() async {
    final integration = _cubit.state.integration;

    if (integration == null) return;

    final confirmed = await showGitHubConfirmation(context,
      title: 'Unlink Repository',
      message:
          'Disconnect "${integration.fullName ?? 'this repository'}" '
          'from this project?\n\n'
          'This project will no longer be connected '
          'to the repository.',
      confirmLabel: 'Unlink',
      destructive: true,
    );

    if (!mounted || !confirmed) return;

    final success = await _cubit.unlinkRepository();

    if (!mounted) return;

    _showActionResult(
      success: success,
      successMessage: 'Repository unlinked successfully.',
      failureMessage: 'Unable to unlink repository.',
    );
  }

  void _showActionResult({
    required bool success,
    required String successMessage,
    required String failureMessage,
  }) {
    final colors = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? successMessage
                : _cubit.state.errorMessage ?? failureMessage,
          ),
          backgroundColor: success ? null : colors.error,
        ),
      );
  }

  // ═══════════════════════════════════════════
  // Main UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectGitHubCubit, ProjectGitHubState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GitHubIntegrationHeader(state: state, onRefresh: _cubit.refreshIntegration),

            const SizedBox(height: 16),

            if (state.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),

            _buildContent(state),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // State Handling
  // ═══════════════════════════════════════════

  Widget _buildContent(ProjectGitHubState state) {
    final integration = state.integration;

    if (integration == null) {
      if (state.status == ProjectGitHubRequestStatus.failure) {
        return GitHubIntegrationError(state: state, onRefresh: _cubit.refreshIntegration);
      }

      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.status == ProjectGitHubRequestStatus.failure) ...[
          GitHubIntegrationError(state: state, onRefresh: _cubit.refreshIntegration),
          const SizedBox(height: 12),
        ],

        if (integration.isMapped) ...[
          GitHubLinkedRepositoryCard(integration: integration),

          const SizedBox(height: 16),

          GitHubSyncCoverageSection(
            integration: integration,
            coverage: state.coverage,
            coverageError: state.coverageError,
            isRefreshing: state.isRefreshing,
          ),

          if (_cubit.canManage) ...[
            const SizedBox(height: 16),

            GitHubManagementActions(state: state, onSync: _requestSync, onUnlink: _unlinkRepository),
          ],
        ] else
          GitHubUnlinkedRepository(state: state, integration: integration, canManage: _cubit.canManage, onSelect: _selectRepository),
      ],
    );
  }

}
