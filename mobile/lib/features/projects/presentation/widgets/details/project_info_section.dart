import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'info_row.dart';

class ProjectInfoSection extends StatelessWidget {
  final ProjectModel project;

  const ProjectInfoSection({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          InfoRow(label: 'Project ID', value: project.id),
          Divider(height: 24, color: theme.dividerColor),
          InfoRow(label: 'Status', value: project.status.value),
          Divider(height: 24, color: theme.dividerColor),
          InfoRow(
            label: 'Start Date',
            value: project.startDate?.toString().split(' ')[0] ?? '-',
          ),
        ],
      ),
    );
  }
}