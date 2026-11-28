import 'package:flutter/material.dart';
import '../details/overview/project_unavailable_tab.dart';

class TasksListView extends StatelessWidget {
  final String projectId;
  final String? filterStatus;
  const TasksListView({super.key, required this.projectId, this.filterStatus});

  @override
  Widget build(BuildContext context) {
    return const ProjectUnavailableTab(
      icon: Icons.task_alt,
      title: 'Tasks unavailable',
      message: 'Task data is not available from the server.',
    );
  }
}
