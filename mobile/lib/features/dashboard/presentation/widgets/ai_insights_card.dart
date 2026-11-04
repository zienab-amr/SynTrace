import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class AiInsightsCard extends StatelessWidget {
  const AiInsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'AI Insights',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text(
                'Open AI →',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightItem(
            context,
            title: 'Sprint Delay Risk',
            subtitle: 'ERP Platform',
            description: 'Three high-priority tasks remain blocked and PR review time has increased by 40%.',
            badgeText: '78%',
            badgeColor: AppColors.warning,
          ),
          const SizedBox(height: 12),
          _buildInsightItem(
            context,
            title: 'Team Velocity Drop',
            subtitle: 'Mobile Customer App',
            description: 'Sarah Chen\'s workload exceeds team average by 2.3x this sprint.',
            badgeText: '52%',
            badgeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required String badgeText,
    required Color badgeColor,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'View Root Cause',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Explore Graph',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}