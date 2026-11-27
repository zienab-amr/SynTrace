import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/core/theme/theme_controller.dart';
import 'package:syntrace/features/settings/presentation/widgets/theme_option_card.dart';
import 'package:syntrace/shared/widgets/design_system/app_card.dart';
import 'package:syntrace/shared/widgets/design_system/app_section_header.dart';

class AppearanceTab extends StatelessWidget {
  const AppearanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Appearance',
            subtitle: 'Personalize your SynTrace experience.',
          ),

          const SizedBox(height: AppSpacing.xl),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme preference', style: context.appText.titleMedium),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Choose how SynTrace looks on this device.',
                  style: context.appText.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeMode,
                  builder: (context, selectedMode, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 260 ? 1 : 3;

                        final itemWidth =
                            (constraints.maxWidth -
                                (columns - 1) * AppSpacing.sm) /
                            columns;

                        return Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: ThemeOptionCard(
                                mode: ThemeMode.light,
                                label: 'Light',
                                icon: AppIcons.sun,
                                selected: selectedMode == ThemeMode.light,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: ThemeOptionCard(
                                mode: ThemeMode.dark,
                                label: 'Dark',
                                icon: AppIcons.moon,
                                selected: selectedMode == ThemeMode.dark,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: ThemeOptionCard(
                                mode: ThemeMode.system,
                                label: 'System',
                                icon: AppIcons.system,
                                selected: selectedMode == ThemeMode.system,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(AppIcons.info, size: 16, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your theme preference is applied immediately '
                  'and stored on this device.',
                  style: context.appText.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
