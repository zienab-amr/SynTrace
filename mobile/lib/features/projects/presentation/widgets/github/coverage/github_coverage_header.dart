import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import '../github_sync_status_badge.dart';

class GitHubCoverageHeader extends StatelessWidget {
  final GitHubSyncStatus status;
  const GitHubCoverageHeader({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),

            const SizedBox(width: 8),

            Text(
              'Sync Coverage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        GitHubSyncStatusBadge(status: status),
      ],
    );
  }

}
