import 'package:flutter/material.dart';
import '../details/overview/project_unavailable_tab.dart';

class HealthOverlayContent extends StatelessWidget {
  final String projectId;
  const HealthOverlayContent({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return const ProjectUnavailableTab(
      icon: Icons.favorite_outline,
      title: 'Health unavailable',
      message: 'Project health metrics are not available from the server.',
    );
  }
}
