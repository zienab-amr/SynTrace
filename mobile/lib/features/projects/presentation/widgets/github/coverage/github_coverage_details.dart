import 'package:flutter/material.dart';
import 'package:syntrace/features/settings/data/models/github_model.dart';
import 'github_coverage_message.dart';
import 'github_coverage_detail_row.dart';

class GitHubCoverageDetails extends StatelessWidget {
  final GitHubSyncCoverage coverage;
  final DateTime? lastSuccessAtUtc;
  const GitHubCoverageDetails({super.key, required this.coverage, this.lastSuccessAtUtc});

  @override
  Widget build(BuildContext context) {
    final data = coverage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GitHubCoverageDetailRow(
          icon: Icons.layers_outlined,
          label: 'Requested version',
          value: data.requestedVersion.toString(),
        ),

        const SizedBox(height: 14),

        GitHubCoverageDetailRow(
          icon: Icons.check_circle_outline,
          label: 'Completed version',
          value: data.completedVersion.toString(),
        ),

        const SizedBox(height: 14),

        GitHubCoverageDetailRow(
          icon: Icons.schedule_rounded,
          label: 'Last successful sync',
          value: _formatDate(
            context,
            data.lastSuccessAtUtc ?? lastSuccessAtUtc,
          ),
        ),

        const SizedBox(height: 14),

        GitHubCoverageDetailRow(
          icon: Icons.commit_rounded,
          label: 'Last indexed revision',
          value: _shortSha(data.lastIndexedHeadSha),
        ),

        const SizedBox(height: 16),

        _buildIndexingInformation(context),
      ],
    );
  }
  Widget _buildIndexingInformation(BuildContext context) {
    final data = coverage;
    final theme = Theme.of(context);

    return GitHubCoverageMessage(
      icon: Icons.info_outline_rounded,
      message: data.hasIndexedHead
          ? 'A code revision has been recorded. '
                'AI indexing completion is not yet '
                'reported by the server.'
          : 'No indexed code revision has been '
                'reported yet.',
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  String _formatDate(BuildContext context, DateTime? date) {
    if (date == null) return 'Not available';

    final localDate = date.toLocal();

    final localizations = MaterialLocalizations.of(context);

    final formattedDate = localizations.formatMediumDate(localDate);

    final formattedTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDate),
    );

    return '$formattedDate, $formattedTime';
  }

  String _shortSha(String? sha) {
    if (sha == null || sha.isEmpty) {
      return 'Not available';
    }

    return sha.length > 7 ? sha.substring(0, 7) : sha;
  }
}
