import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/theme_controller.dart';
import 'package:syntrace/features/settings/presentation/widgets/theme_preview.dart';

class ThemeOptionCard extends StatelessWidget {
  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;

  const ThemeOptionCard({
    super.key,
    required this.mode,
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: Material(
        color: selected ? colors.selected : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(
            color: selected ? primary : colors.borderStrong,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await ThemeController.setTheme(mode);
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ThemePreview(mode: mode),

                const SizedBox(height: AppSpacing.md),

                Icon(
                  icon,
                  size: 20,
                  color: selected ? primary : colors.textSecondary,
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  label,
                  style: context.appText.labelMedium?.copyWith(
                    color: selected ? primary : colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.sm),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? AppIcons.success : Icons.radio_button_unchecked,
                    key: ValueKey(selected),
                    size: 18,
                    color: selected ? primary : colors.borderStrong,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
