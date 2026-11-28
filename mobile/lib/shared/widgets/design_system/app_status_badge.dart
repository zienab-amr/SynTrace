import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_text_styles.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

enum AppStatusTone { neutral, success, warning, error, info }

class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool showDot;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final (foreground, background) = switch (tone) {
      AppStatusTone.neutral => (colors.textSecondary, colors.surfaceMuted),
      AppStatusTone.success => (colors.success, colors.successSurface),
      AppStatusTone.warning => (colors.warning, colors.warningSurface),
      AppStatusTone.error => (colors.error, colors.errorSurface),
      AppStatusTone.info => (scheme.primary, colors.infoSurface),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
