import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/theme_controller.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';

class FinishStep extends StatelessWidget {
  final OnboardingData data;

  const FinishStep({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fact_check_outlined,
              size: 42,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to get started?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Review your setup before entering SynTrace.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          _SummaryItem(
            icon: Icons.business_outlined,
            label: 'Organization',
            value: data.organizationName.isEmpty
                ? 'Unavailable'
                : data.organizationName,
          ),
          _SummaryItem(
            icon: Icons.group_add_outlined,
            label: 'Pending members',
            value: '${data.teamMembers.length}',
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              final label = switch (mode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'System',
              };

              return _SummaryItem(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                value: label,
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            data.teamMembers.isEmpty
                ? 'Continue to open your workspace.'
                : 'Pending member accounts will be created '
                      'when you complete setup.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
