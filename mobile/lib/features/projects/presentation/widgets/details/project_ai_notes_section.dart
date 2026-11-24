import 'package:flutter/material.dart';
import 'project_team_notes_section.dart';

class ProjectAiNotesSection extends StatelessWidget {
  final String projectId;
  const ProjectAiNotesSection({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return ProjectTeamNotesSection(projectId: projectId, publishedOnly: true);
  }
}
