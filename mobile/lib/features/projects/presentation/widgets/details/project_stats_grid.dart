import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';
import 'stat_card.dart';

class ProjectStatsGrid extends StatelessWidget {
  final ProjectStats stats;
  final VoidCallback? onHealthTap;
  final VoidCallback? onTasksTap;
  final VoidCallback? onBlockedTap;
  final VoidCallback? onPRsTap;
  final VoidCallback? onCommitsTap;

  const ProjectStatsGrid({
    super.key,
    required this.stats,
    this.onHealthTap,
    this.onTasksTap,
    this.onBlockedTap,
    this.onPRsTap,
    this.onCommitsTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 600 ? 2 : (width < 1024 ? 3 : 5);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            StatCard(
              label: 'Health',
              value: '${stats.healthPercent}%',
              color: stats.healthPercent > 80
                  ? AppColors.secondary
                  : stats.healthPercent > 60
                      ? AppColors.warning
                      : AppColors.error,
              icon: Icons.favorite_outline,
              onTap: onHealthTap,
            ),
            StatCard(
              label: 'Open Tasks',
              value: '${stats.openTasks}',
              color: AppColors.primary,
              icon: Icons.task_alt,
              onTap: onTasksTap,
            ),
            StatCard(
              label: 'Blocked',
              value: '${stats.blockedTasks}',
              color: AppColors.error,
              icon: Icons.block,
              onTap: onBlockedTap,
            ),
            StatCard(
              label: 'PRs',
              value: '${stats.pullRequests}',
              color: AppColors.primaryLight,
              icon: Icons.merge,
              onTap: onPRsTap,
            ),
            StatCard(
              label: 'Commits',
              value: '${stats.commitsCount}',
              color: AppColors.secondary,
              icon: Icons.commit,
              onTap: onCommitsTap,
            ),
          ],
        );
      },
    );
  }
}