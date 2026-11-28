import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'github_details_section.dart';
import 'github_information_message.dart';

class GitHubCommitReferencesSection extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubCommitReferencesSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GitHubDetailsSection(
      title: 'Related Commits',
      icon: Icons.commit,
      children: [
        if (item.commitShas.isEmpty)
          const GitHubInformationMessage(
            icon: Icons.info_outline,
            message: 'No commit references were returned.',
          ),

        ...item.commitShas.map(
          (sha) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.commit, size: 18),

                const SizedBox(width: 10),

                Expanded(child: SelectableText(sha)),
              ],
            ),
          ),
        ),

        if (item.commitsMayBeIncomplete)
          const GitHubInformationMessage(
            icon: Icons.info_outline,
            message: 'The returned commit list may be incomplete.',
          ),
      ],
    );
  }
}
