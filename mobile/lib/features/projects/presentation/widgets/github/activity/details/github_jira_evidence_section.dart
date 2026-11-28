import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'package:syntrace/core/utils/secure_source_link.dart';
import 'github_details_section.dart';
import 'github_information_message.dart';
import 'github_activity_link_feedback.dart';

class GitHubJiraEvidenceSection extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubJiraEvidenceSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GitHubDetailsSection(
      title: 'Jira Evidence',
      icon: Icons.link_rounded,
      children: [
        if (!item.hasJiraEvidence)
          const GitHubInformationMessage(
            icon: Icons.link_off_rounded,
            message:
                'No Jira references were returned '
                'for this activity.',
          ),

        ...item.jira.map((issue) => _JiraIssueCard(issue: issue)),

        if (item.unresolvedJiraKeys.isNotEmpty) ...[
          const SizedBox(height: 12),

          Text(
            'Unresolved References',
            style: Theme.of(context).textTheme.titleSmall,
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: item.unresolvedJiraKeys
                .map(
                  (key) => Chip(
                    avatar: const Icon(Icons.link_off_rounded, size: 16),
                    label: Text(key),
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 8),

          const GitHubInformationMessage(
            icon: Icons.info_outline,
            message:
                'These references could not be resolved '
                'to Jira issues in the current project.',
          ),
        ],
      ],
    );
  }
}

class _JiraIssueCard extends StatelessWidget {
  final GitHubJiraReference issue;

  const _JiraIssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final hasLink = SecureSourceLink.jiraUri(issue.url) != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  issue.key,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              if (hasLink)
                IconButton(
                  tooltip: 'Open Jira issue',
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  onPressed: () async {
                    final opened = await SecureSourceLink.openJira(issue.url);

                    if (!context.mounted) return;

                    if (!opened) {
                      showGitHubActivityLinkError(context);
                    }
                  },
                ),
            ],
          ),

          if (issue.summary != null && issue.summary!.trim().isNotEmpty)
            Text(issue.summary!, style: theme.textTheme.bodyMedium),

          if (issue.status != null) ...[
            const SizedBox(height: 8),

            Chip(label: Text(issue.status!)),
          ],

          if (!hasLink)
            const GitHubInformationMessage(
              icon: Icons.link_off_rounded,
              message: 'Source link unavailable.',
            ),
        ],
      ),
    );
  }
}
