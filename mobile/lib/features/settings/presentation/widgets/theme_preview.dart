import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';

class ThemePreview extends StatelessWidget {
  final ThemeMode mode;

  const ThemePreview({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 1.15,
        child: ClipRRect(
          borderRadius: AppRadius.small,
          child: mode == ThemeMode.system
              ? const Row(
                  children: [
                    Expanded(child: _PreviewCanvas(isDark: false)),
                    Expanded(child: _PreviewCanvas(isDark: true)),
                  ],
                )
              : _PreviewCanvas(isDark: mode == ThemeMode.dark),
        ),
      ),
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  final bool isDark;

  const _PreviewCanvas({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    final border = isDark
        ? AppColors.borderStrongDark
        : AppColors.borderStrongLight;

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            height: 14,
            color: surface,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    flex: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  const SizedBox(width: 3),

                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.7,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: border,
                              borderRadius: AppRadius.pill,
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              border: Border.all(color: border, width: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        const SizedBox(height: 3),

                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              border: Border.all(color: border, width: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        FractionallySizedBox(
                          widthFactor: 0.65,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
