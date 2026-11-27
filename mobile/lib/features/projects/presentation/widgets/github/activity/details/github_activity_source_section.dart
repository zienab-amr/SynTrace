import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'package:syntrace/core/utils/secure_source_link.dart';
import 'github_details_section.dart';
import 'github_information_message.dart';
import 'github_activity_link_feedback.dart';

class GitHubSourceSection extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubSourceSection({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final hasLink = SecureSourceLink.githubUri(item.url) != null;

    return GitHubDetailsSection(
      title: 'Original Source',
      icon: Icons.open_in_new_rounded,
      children: [
        if (hasLink)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(
                item.isCommit
                    ? 'View commit on GitHub'
                    : 'View pull request on GitHub',
              ),
              onPressed: () async {
                final opened = await SecureSourceLink.openGitHub(item.url);

                if (!context.mounted) return;

                if (!opened) {
                  showGitHubActivityLinkError(context);
                }
              },
            ),
          )
        else
          const GitHubInformationMessage(
            icon: Icons.link_off_rounded,
            message: 'GitHub source link unavailable.',
          ),

        const SizedBox(height: 8),

        const GitHubInformationMessage(
          icon: Icons.lock_outline,
          message:
              'Access to the original source is subject '
              'to your GitHub account permissions.',
        ),
      ],
    );
  }
}
