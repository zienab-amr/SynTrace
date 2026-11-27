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

  const GitHubUnlinkedRepository({
    super.key,
    required this.state,
    required this.integration,
    required this.canManage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final unavailable = integration.isUnavailable;

    final title = unavailable
        ? 'GitHub unavailable'
        : integration.canSelectRepository
        ? 'No repository linked'
        : 'Repository status unavailable';

    final description = unavailable
        ? 'Check your company GitHub integration.'
        : canManage
        ? 'Connect your project\'s repository.'
        : 'Contact your company administrator.';

    final canLink = canManage && integration.canSelectRepository;

    final isEnabled =
        state.canSelectRepository &&
        state.status == ProjectGitHubRequestStatus.success;

    return GitHubIntegrationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  unavailable
                      ? Icons.cloud_off_outlined
                      : Icons.link_off_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(description, style: theme.textTheme.bodySmall),

                    const SizedBox(height: 8),

                    GitHubSyncStatusBadge(status: integration.syncStatus),
                  ],
                ),
              ),
            ],
          ),

          if (canLink) ...[
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isEnabled ? onSelect : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Link repository'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
