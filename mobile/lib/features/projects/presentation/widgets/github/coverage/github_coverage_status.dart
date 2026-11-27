import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'github_coverage_message.dart';
import 'github_coverage_processing.dart';

class GitHubCoverageStatus extends StatelessWidget {
  final GitHubSyncStatus status;
  final GitHubSyncCoverage? coverage;
  final bool isRefreshing;
  const GitHubCoverageStatus({
    super.key,
    required this.status,
    this.coverage,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case GitHubSyncStatus.pending:
        return GitHubCoverageProcessing(
          coverage: coverage,
          isRefreshing: isRefreshing,
          title: 'Synchronizing repository',
          description:
              'Repository data is being imported '
              'or waiting to be processed.',
        );

      case GitHubSyncStatus.retrying:
        return GitHubCoverageProcessing(
          coverage: coverage,
          isRefreshing: isRefreshing,
          title: 'Retrying synchronization',
          description:
              'The server is retrying the '
              'repository synchronization.',
          isRetrying: true,
        );

      case GitHubSyncStatus.synced:
        return GitHubCoverageMessage(
          icon: Icons.check_circle_outline_rounded,
          message: 'Repository synchronization is complete.',
          color: Colors.green.shade600,
        );

      case GitHubSyncStatus.unavailable:
        return GitHubCoverageMessage(
          icon: Icons.cloud_off_outlined,
          message:
              'The GitHub integration is currently '
              'unavailable.',
          color: Theme.of(context).colorScheme.error,
        );

      case GitHubSyncStatus.notMapped:
        return GitHubCoverageMessage(
          icon: Icons.link_off_rounded,
          message: 'No repository is linked to this project.',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

      case GitHubSyncStatus.unknown:
        return GitHubCoverageMessage(
          icon: Icons.help_outline_rounded,
          message: 'The synchronization status is unknown.',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    }
  }
}
