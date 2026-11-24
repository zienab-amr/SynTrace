import 'package:flutter/material.dart';
import '../../../../data/models/project_api_model.dart';
import 'project_overview_title.dart';
import 'project_overview_surface.dart';
import 'project_information_row.dart';

class ProjectInformationSection extends StatelessWidget {
  final ProjectApiModel project;
  const ProjectInformationSection({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final description = project.description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ProjectOverviewTitle(title: 'Project Information'),

        const SizedBox(height: 12),

        ProjectOverviewSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Text(
                description == null || description.isEmpty
                    ? 'No description provided.'
                    : description,

                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              const Divider(),

              const SizedBox(height: 12),

              ProjectInformationRow(
                icon: Icons.info_outline_rounded,
                label: 'Status',
                value: project.status?.label ?? 'Not available',
              ),

              const SizedBox(height: 14),

              ProjectInformationRow(
                icon: Icons.link_rounded,
                label: 'Jira integration',
                value: project.hasJiraProject ? 'Linked' : 'Not linked',
              ),

              if (project.hasJiraProject) ...[
                const SizedBox(height: 14),

                ProjectInformationRow(
                  icon: Icons.assignment_outlined,
                  label: 'Jira project ID',
                  value: project.jiraProjectId!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
