import 'package:flutter/material.dart';

import '../../data/models/project_api_model.dart';

class ProjectCard extends StatelessWidget {
  final ProjectApiModel project;
  final VoidCallback? onTap;

  const ProjectCard({super.key, required this.project, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final description = project.description?.trim();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),

            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,

                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Icon(Icons.folder_outlined, color: colors.primary),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                description == null || description.isEmpty
                    ? 'No description provided.'
                    : description,

                maxLines: 3,

                overflow: TextOverflow.ellipsis,

                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              const Divider(),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildJiraBadge(context),

                  if (project.status != null &&
                      project.status != ProjectApiStatus.unknown)
                    _buildBadge(
                      context,
                      icon: Icons.info_outline,
                      label: project.status!.label,
                      color: colors.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJiraBadge(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return _buildBadge(
      context,

      icon: project.hasJiraProject
          ? Icons.link_rounded
          : Icons.link_off_rounded,

      label: project.hasJiraProject ? 'Jira Linked' : 'Jira Not Linked',

      color: project.hasJiraProject ? colors.primary : colors.onSurfaceVariant,
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),

          const SizedBox(width: 6),

          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
