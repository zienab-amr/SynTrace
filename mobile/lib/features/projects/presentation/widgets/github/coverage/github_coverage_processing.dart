import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';

class GitHubCoverageProcessing extends StatelessWidget {
  final String title;
  final String description;
  final bool isRetrying;
  final GitHubSyncCoverage? coverage;
  final bool isRefreshing;
  const GitHubCoverageProcessing({
    super.key,
    required this.title,
    required this.description,
    this.isRetrying = false,
    this.coverage,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = isRetrying
        ? Colors.orange.shade700
        : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.1),
          ),
        ),

        if (coverage != null) ...[
          const SizedBox(height: 12),

          Text(
            'Current phase: ${coverage!.phaseLabel}',
            style: theme.textTheme.bodySmall,
          ),
        ],

        const SizedBox(height: 8),

        Text(
          isRefreshing
              ? 'Refreshing status...'
              : 'Status updates automatically.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
