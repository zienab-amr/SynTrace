import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import '../../../cubit/github/project_github_state.dart';
import 'github_integration_surface.dart';
import '../github_sync_status_badge.dart';

class GitHubUnlinkedRepository extends StatelessWidget {
  final ProjectGitHubState state;
  final GitHubProjectStatus integration;
  final bool canManage;
  final VoidCallback onSelect;
  const GitHubUnlinkedRepository({super.key, required this.state, required this.integration, required this.canManage, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final unavailable = integration.isUnavailable;

    return GitHubIntegrationSurface(
      child: Column(
        children: [
          Icon(
            unavailable ? Icons.cloud_off_outlined : Icons.link_off_rounded,
            size: 44,
            color: colors.onSurfaceVariant,
          ),

          const SizedBox(height: 16),

          Text(
            unavailable
                ? 'GitHub unavailable'
                : integration.canSelectRepository
                ? 'No repository linked'
                : 'Repository status unavailable',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            unavailable
                ? 'Check your company GitHub integration.'
                : canManage
                ? 'Connect a repository to import '
                      'commits, pull requests and code.'
                : 'A company administrator can '
                      'connect a repository to this project.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),

          const SizedBox(height: 16),

          GitHubSyncStatusBadge(status: integration.syncStatus),

          if (canManage && integration.canSelectRepository) ...[
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    state.canSelectRepository &&
                        state.status == ProjectGitHubRequestStatus.success
                    ? onSelect
                    : null,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Link Repository'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
