import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'github_integration_surface.dart';

class GitHubLinkedRepositoryCard extends StatelessWidget {
  final GitHubProjectStatus integration;
  const GitHubLinkedRepositoryCard({super.key, required this.integration});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GitHubIntegrationSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_outlined, color: colors.primary),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      integration.fullName ?? 'Linked repository',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text('GitHub Repository', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),

              Icon(Icons.link_rounded, color: colors.primary),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 18,
                color: colors.onSurfaceVariant,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text('Default branch', style: theme.textTheme.bodySmall),
              ),

              Flexible(
                child: Text(
                  integration.defaultBranch ?? 'Not available',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
