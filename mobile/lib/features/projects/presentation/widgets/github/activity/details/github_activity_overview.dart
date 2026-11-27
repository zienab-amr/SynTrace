import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'github_details_section.dart';

class GitHubActivityOverview extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubActivityOverview({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final description = item.isCommit ? item.message : item.body;

    return GitHubDetailsSection(
      title: item.isCommit ? 'Commit Overview' : 'Pull Request Overview',
      icon: item.isCommit ? Icons.commit : Icons.call_split_rounded,
      children: [
        Text(
          item.displayTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(item.statusLabel)),
            if (!item.isCommit) Chip(label: Text('#${item.number}')),
          ],
        ),

        if (description != null &&
            description.trim().isNotEmpty &&
            description.trim() != item.displayTitle) ...[
          const SizedBox(height: 12),

          SelectableText(description, style: theme.textTheme.bodyMedium),
        ],

        if (!item.isCommit &&
            (description == null || description.trim().isEmpty)) ...[
          const SizedBox(height: 12),

          Text(
            'No description provided.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
