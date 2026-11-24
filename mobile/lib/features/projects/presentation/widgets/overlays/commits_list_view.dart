import 'package:flutter/material.dart';

import '../../../data/models/github_activity_model.dart';
import '../github/activity/github_activity_section.dart';

class CommitsListView extends StatelessWidget {
  final String projectId;

  const CommitsListView({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return GitHubActivitySection(
      projectId: projectId,
      kind: GitHubActivityKind.commit,
    );
  }
}
