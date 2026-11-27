import 'package:flutter/material.dart';
import 'project_overview_surface.dart';

class ProjectUnavailableCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const ProjectUnavailableCard({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ProjectOverviewSurface(
      child: Row(
        children: [
          Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
