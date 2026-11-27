import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import 'package:syntrace/features/projects/data/models/project_api_model.dart';
import 'package:syntrace/shared/widgets/app_icon.dart';

class DashboardProjectTile extends StatelessWidget {
  final ProjectApiModel project;

  const DashboardProjectTile({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;
    final scheme = Theme.of(context).colorScheme;

    final status = project.status;

    final hasKnownStatus = status != null && status != ProjectApiStatus.unknown;

    final subtitle = hasKnownStatus
        ? status.label
        : project.hasJiraProject
        ? 'Jira linked'
        : 'No Jira project linked';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          AppRoutes.projectDetailsById(Uri.encodeComponent(project.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border, width: 0.7),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  AppPremiumIcons.projects,
                  size: 21,
                  strokeWidth: 1.6,
                  color: scheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        letterSpacing: -0.15,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              AppIcon(
                AppPremiumIcons.forward,
                size: 16,
                strokeWidth: 1.5,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
