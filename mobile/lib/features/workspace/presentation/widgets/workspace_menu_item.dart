import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

class WorkspaceMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const WorkspaceMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadius.medium,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: colors.textSecondary),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.appText.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: context.appText.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            Icon(AppIcons.chevronRight, size: 17, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
