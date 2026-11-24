import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/models/github_activity_model.dart';
import 'details/github_activity_overview.dart';
import 'details/github_activity_metadata.dart';
import 'details/github_jira_evidence_section.dart';
import 'details/github_changed_files_section.dart';
import 'details/github_commit_references_section.dart';
import 'details/github_activity_source_section.dart';

class GitHubActivityDetails extends StatelessWidget {
  final GitHubActivityItem item;

  const GitHubActivityDetails({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.isCommit ? 'Commit Details' : 'Pull Request Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GitHubActivityOverview(item: item),

            const SizedBox(height: 16),

            GitHubActivityMetadata(item: item),

            const SizedBox(height: 16),

            GitHubJiraEvidenceSection(item: item),

            const SizedBox(height: 16),

            GitHubChangedFilesSection(item: item),

            if (!item.isCommit) ...[
              const SizedBox(height: 16),
              GitHubCommitReferencesSection(item: item),
            ],

            const SizedBox(height: 16),

            GitHubSourceSection(item: item),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
