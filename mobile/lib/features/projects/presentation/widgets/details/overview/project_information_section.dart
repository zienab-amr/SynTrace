import 'package:flutter/material.dart';

import '../../../../data/models/project_api_model.dart';

import 'package:syntrace/shared/widgets/design_system/design_system.dart';

class ProjectInformationSection extends StatelessWidget {
  final ProjectApiModel project;

  const ProjectInformationSection({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = project.description?.trim();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Project overview',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              AppStatusBadge(
                label: project.status?.label ?? 'Unknown',
                tone: _statusTone(project.status),
              ),
            ],
          ),

          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: theme.textTheme.bodySmall),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                Icons.link_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jira integration',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppStatusBadge(
                label: project.hasJiraProject ? 'Linked' : 'Not linked',
                tone: project.hasJiraProject
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppStatusTone _statusTone(ProjectApiStatus? status) {
    switch (status) {
      case ProjectApiStatus.completed:
        return AppStatusTone.success;

      case ProjectApiStatus.inProgress:
        return AppStatusTone.info;

      case ProjectApiStatus.onHold:
        return AppStatusTone.warning;

      case ProjectApiStatus.cancelled:
        return AppStatusTone.error;

      default:
        return AppStatusTone.neutral;
    }
  }
}
