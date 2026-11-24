import 'package:flutter/material.dart';
import '../../../../data/models/project_api_model.dart';
import 'project_information_section.dart';
import 'project_unavailable_card.dart';
import 'project_overview_title.dart';

class ProjectOverview extends StatelessWidget {
  final ProjectApiModel project;
  final Widget githubIntegration;
  const ProjectOverview({super.key, required this.project, required this.githubIntegration});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProjectInformationSection(project: project),

          const SizedBox(height: 24),

          githubIntegration,

          const SizedBox(height: 24),

          const ProjectUnavailableOverviewSection(title: 'Team Members', icon: Icons.groups_outlined, message: 'Project member information is currently unavailable.'),

          const SizedBox(height: 24),

          const ProjectUnavailableOverviewSection(title: 'Project Statistics', icon: Icons.analytics_outlined, message: 'Project statistics are currently unavailable.'),

          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class ProjectUnavailableOverviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  const ProjectUnavailableOverviewSection({super.key, required this.title, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ProjectOverviewTitle(title: title), const SizedBox(height: 12), ProjectUnavailableCard(icon: icon, message: message)]);
}
