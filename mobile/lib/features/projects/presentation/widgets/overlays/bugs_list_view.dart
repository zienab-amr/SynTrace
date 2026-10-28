import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class BugsListView extends StatelessWidget {
  const BugsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: MockBugs.bugs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bug = MockBugs.bugs[index];
        return _BugTile(bug: bug);
      },
    );
  }
}

class _BugTile extends StatelessWidget {
  final MockBugItem bug;

  const _BugTile({required this.bug});

  @override
  Widget build(BuildContext context) {
    final severityColor = switch (bug.severity) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      'medium' => AppColors.primary,
      _ => AppColors.textMuted,
    };

    final isResolved = bug.status == 'resolved';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isResolved ? Icons.check_circle : Icons.bug_report,
            color: isResolved ? AppColors.secondary : severityColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      bug.id,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        bug.severity.toUpperCase(),
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  bug.title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}