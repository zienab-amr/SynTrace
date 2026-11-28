import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'github_details_section.dart';
import 'github_metadata_row.dart';
import 'github_information_message.dart';

class GitHubActivityMetadata extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubActivityMetadata({super.key, required this.item});

  String? _formatDate(BuildContext context, DateTime? value) {
    if (value == null) return null;

    final local = value.toLocal();
    final localizations = MaterialLocalizations.of(context);

    final date = localizations.formatMediumDate(local);

    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));

    return '$date • $time';
  }

  @override
  Widget build(BuildContext context) {
    return GitHubDetailsSection(
      title: 'Activity Information',
      icon: Icons.info_outline_rounded,
      children: [
        GitHubMetadataRow(label: 'Author', value: item.authorLogin),

        GitHubMetadataRow(
          label: 'Commit SHA',
          value: item.sha,
          selectable: true,
        ),

        GitHubMetadataRow(label: 'Head branch', value: item.headRef),

        GitHubMetadataRow(label: 'Base branch', value: item.baseRef),

        GitHubMetadataRow(
          label: 'Head SHA',
          value: item.headSha,
          selectable: true,
        ),

        GitHubMetadataRow(
          label: 'Merge commit',
          value: item.mergeCommitSha,
          selectable: true,
        ),

        GitHubMetadataRow(
          label: 'Authored at',
          value: _formatDate(context, item.authoredAt),
        ),

        GitHubMetadataRow(
          label: 'Committed at',
          value: _formatDate(context, item.commitDate),
        ),

        GitHubMetadataRow(
          label: 'Created at',
          value: _formatDate(context, item.createdAt),
        ),

        GitHubMetadataRow(
          label: 'Updated at',
          value: _formatDate(context, item.updatedAt),
        ),

        GitHubMetadataRow(
          label: 'Merged at',
          value: _formatDate(context, item.mergedAt),
        ),

        GitHubMetadataRow(
          label: 'Closed at',
          value: _formatDate(context, item.closedAt),
        ),

        if (item.linkedAuthor != null)
          const GitHubInformationMessage(
            icon: Icons.verified_user_outlined,
            message: 'Author linked to a SynTrace employee.',
          ),

        if (item.linkedMergedBy != null)
          const GitHubInformationMessage(
            icon: Icons.verified_user_outlined,
            message: 'Merge author linked to a SynTrace employee.',
          ),
      ],
    );
  }
}
