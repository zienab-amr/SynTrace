import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class PRsListView extends StatelessWidget 
{
  final String projectId;
  const PRsListView({super.key, required this.projectId});
  @override
  Widget build(BuildContext context)
  {
    final prs = MockPRs.getByProject(projectId);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: prs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final pr = prs[index];
        return _PRTile(pr: pr);
      },
    );
  }
}

class _PRTile extends StatelessWidget {
  final MockPRItem pr;

  const _PRTile({required this.pr});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (pr.status) {
      'merged' => (AppColors.secondary, 'Merged'),
      'closed' => (AppColors.error, 'Closed'),
      _ => (AppColors.primary, 'Open'),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.merge, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              Text(
                pr.id,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pr.title,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                pr.authorName,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '+${pr.additions}',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '-${pr.deletions}',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}