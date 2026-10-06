import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/onboarding/data/onboarding_data.dart';

class FinishStep extends StatelessWidget {
  final OnboardingData data;

  const FinishStep({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // ─── Success Icon ───
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withOpacity(0.15),
            ),
            child: const Center(
              child: Icon(
                Icons.check_circle_outline,
                size: 56,
                color: AppColors.secondary,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ─── Title ───
          Text(
            "You're all set!",
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Here\'s a quick summary:',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          // ─── Summary ───
          _SummaryItem(
            icon: Icons.business_outlined,
            label: 'Organization',
            value: data.organizationName,
          ),
          _SummaryItem(
            icon: Icons.category_outlined,
            label: 'Industry',
            value: data.industry,
          ),
          _SummaryItem(
            icon: Icons.groups_outlined,
            label: 'Team Size',
            value: data.teamSize,
          ),
          if (data.teamEmails.isNotEmpty)
            _SummaryItem(
              icon: Icons.email_outlined,
              label: 'Invited',
              value: '${data.teamEmails.length} team members',
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}