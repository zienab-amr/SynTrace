import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ProjectOverviewCard extends StatelessWidget {
  const ProjectOverviewCard({super.key});

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Project Overview',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'View all →',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProjectRow(context, 'ERP Platform v3.0', 'Sprint 14 · 6d remaining', 0.57, 'High', AppColors.error),
          const SizedBox(height: 16),
          _buildProjectRow(context, 'Mobile Customer App', 'Sprint 8 · 4d remaining', 0.74, 'Medium', AppColors.warning),
          const SizedBox(height: 16),
          _buildProjectRow(context, 'API Gateway Rewrite', 'Sprint 3 · 9d remaining', 0.32, 'Low', AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildProjectRow(
    BuildContext context,
    String title,
    String subtitle,
    double progress,
    String risk,
    Color riskColor,
  ) {
    final theme = Theme.of(context);

    return Column(
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
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              risk,
              style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: theme.dividerColor.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    riskColor == AppColors.error ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}