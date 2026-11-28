import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_text_styles.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, destructive }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final scheme = theme.colorScheme;

    final foreground = switch (variant) {
      AppButtonVariant.primary => scheme.onPrimary,
      AppButtonVariant.secondary => scheme.primary,
      AppButtonVariant.outline => colors.textPrimary,
      AppButtonVariant.ghost => scheme.primary,
      AppButtonVariant.destructive => colors.error,
    };

    final background = switch (variant) {
      AppButtonVariant.primary => scheme.primary,
      AppButtonVariant.secondary => colors.selected,
      AppButtonVariant.outline => Colors.transparent,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.destructive => colors.errorSurface,
    };

    final callback = isLoading ? null : onPressed;

    final button = TextButton(
      onPressed: callback,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.textSecondary,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: variant == AppButtonVariant.outline
              ? BorderSide(color: colors.borderStrong)
              : BorderSide.none,
        ),
        textStyle: AppTextStyles.button,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          if (!isLoading && trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(trailingIcon, size: 18),
          ],
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
