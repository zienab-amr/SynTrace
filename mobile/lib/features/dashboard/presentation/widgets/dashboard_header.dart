import 'package:flutter/material.dart';

import 'package:syntrace/core/theme/app_theme_extension.dart';

class DashboardHeader extends StatelessWidget {
  final String name;
  final String? companyName;

  const DashboardHeader({super.key, required this.name, this.companyName});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = context.appText;

    final firstName = name.trim().split(RegExp(r'\s+')).first;

    final company = companyName?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR ENGINEERING HUB',
          style: text.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          company != null && company.isNotEmpty ? company : 'Workspace',
          style: text.headlineSmall?.copyWith(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            color: colors.textPrimary,
          ),
        ),
        if (firstName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Welcome back, $firstName.',
            style: text.bodySmall?.copyWith(
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
