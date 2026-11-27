import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';

import '../../data/models/dashboard_models.dart';

import 'dashboard_project_tile.dart';
import 'dashboard_feedback.dart';

class DashboardProjectsSection extends StatelessWidget {
  final DashboardData data;
  final bool isAdmin;
  final VoidCallback onRetry;

  const DashboardProjectsSection({
    super.key,
    required this.data,
    required this.isAdmin,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    final projects = data.previewProjects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your projects',
                style: text.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: colors.textPrimary,
                ),
              ),
            ),

            TextButton(
              onPressed: () => context.go(AppRoutes.projects),
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 48),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all',
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),

                  const SizedBox(width: 6),

                  AppIcon(
                    AppPremiumIcons.forward,
                    size: 14,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        if (data.projects == null)
          DashboardFeedback(
            icon: Icons.cloud_off_outlined,
            message: data.projectsError ?? 'Project data is unavailable.',
            actionLabel: 'Try again',
            onAction: onRetry,
          )
        else if (projects.isEmpty)
          DashboardFeedback(
            icon: Icons.folder_open_outlined,
            message: 'No projects available yet.',
            actionLabel: isAdmin ? 'Create a project' : null,
            onAction: isAdmin
                ? () => context.push(AppRoutes.createProject)
                : null,
          )
        else
          Column(
            children: [
              for (var i = 0; i < projects.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 0.7, color: colors.border),

                DashboardProjectTile(project: projects[i]),
              ],
            ],
          ),
      ],
    );
  }
}
