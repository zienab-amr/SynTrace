import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_text_styles.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/shared/widgets/design_system/app_card.dart';

class WorkspaceMenuSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const WorkspaceMenuSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.overline.copyWith(color: colors.textSecondary),
          ),
        ),

        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(indent: 58, endIndent: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
