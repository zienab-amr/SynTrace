import 'package:flutter/material.dart';

import 'package:syntrace/features/settings/data/models/github_model.dart';

import 'coverage/github_coverage_header.dart';
import 'coverage/github_coverage_status.dart';
import 'coverage/github_coverage_details.dart';
import 'coverage/github_coverage_failure.dart';
import 'coverage/github_coverage_message.dart';

class GitHubSyncCoverageSection extends StatelessWidget {
  final GitHubProjectStatus integration;
  final GitHubSyncCoverage? coverage;
  final String? coverageError;
  final bool isRefreshing;

  const GitHubSyncCoverageSection({
    super.key,
    required this.integration,
    this.coverage,
    this.coverageError,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GitHubCoverageHeader(status: integration.syncStatus),

          const SizedBox(height: 20),

          GitHubCoverageStatus(status: integration.syncStatus, coverage: coverage, isRefreshing: isRefreshing),

          if (coverage != null) ...[
            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 16),

            GitHubCoverageDetails(coverage: coverage!, lastSuccessAtUtc: integration.lastSuccessAtUtc),
          ],

          if (coverageError?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),

            GitHubCoverageMessage(
              icon: Icons.info_outline_rounded,
              message: coverageError!,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],

          if (coverage?.hasFailure ?? false) ...[
            const SizedBox(height: 16),

            GitHubCoverageFailure(message: coverage!.lastFailure!),
          ],
        ],
      ),
    );
  }
}
