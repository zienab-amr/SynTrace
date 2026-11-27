import 'package:flutter/material.dart';
import '../../../data/models/github_activity_model.dart';
import '../github/activity/github_activity_section.dart';

class PRsListView extends StatelessWidget {
  final String projectId;
  const PRsListView({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) => GitHubActivitySection(
    projectId: projectId,
    kind: GitHubActivityKind.pullRequest,
  );
}
