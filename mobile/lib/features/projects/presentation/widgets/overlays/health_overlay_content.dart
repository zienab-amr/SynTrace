import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class HealthOverlayContent extends StatelessWidget {
  final String projectId;

  const HealthOverlayContent({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final totalTasks = MockTasks.totalCount(projectId);
    final doneTasks = MockTasks.doneCount(projectId);
    final blockedTasks = MockTasks.blockedCount(projectId);
    final openBugs = MockBugs.openCount(projectId);
    final commits = MockCommits.count(projectId);

    final safeTotal = totalTasks == 0 ? 1 : totalTasks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _HealthFactor(
            label: 'Completed Tasks',
            value: '$doneTasks / $totalTasks',
            impact: '+${((doneTasks / safeTotal) * 50).toInt()}',
            color: const Color(0xFF10B981),
          ),
          _HealthFactor(
            label: 'Blocked Tasks',
            value: '$blockedTasks',
            impact: '-${((blockedTasks / safeTotal) * 25).toInt()}',
            color: const Color(0xFFEF4444),
          ),
          _HealthFactor(
            label: 'Open Bugs',
            value: '$openBugs',
            impact: '-${(openBugs * 1.5).toInt()}',
            color: const Color(0xFFF59E0B),
          ),
          _HealthFactor(
            label: 'Recent Commits',
            value: '$commits',
            impact: '+${(commits * 1.2).toInt()}',
            color: const Color(0xFF3B82F6),
          ),
        ],
      ),
    );
  }
}

class _HealthFactor extends StatelessWidget {
  final String label;
  final String value;
  final String impact;
  final Color color;

  const _HealthFactor({
    required this.label,
    required this.value,
    required this.impact,
    required this.color,
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
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            impact,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}