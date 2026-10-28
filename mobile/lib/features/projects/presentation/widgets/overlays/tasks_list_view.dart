import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class TasksListView extends StatelessWidget {
  final String projectId;
  final String? filterStatus;   // ← جديد (مثلاً 'blocked')

  const TasksListView({
    super.key,
    required this.projectId,
    this.filterStatus,
  });

  @override
  Widget build(BuildContext context) {
    // ─── Filter ───
    var tasks = MockTasks.getByProject(projectId);
    if (filterStatus != null) {
      tasks = tasks.where((t) => t.status == filterStatus).toList();
    }

    if (tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tasks found',
            style: TextStyle(color: AppColors.textSecondaryDark),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _TaskTile(task: tasks[index]),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final MockTaskItem task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (task.status) {
      'done' => (AppColors.secondary, 'Done'),
      'in_progress' => (AppColors.primary, 'In Progress'),
      'blocked' => (AppColors.error, 'Blocked'),
      _ => (AppColors.textMuted, 'Todo'),
    };

    final priorityColor = switch (task.priority) {
      'critical' => AppColors.error,
      'high' => AppColors.warning,
      'medium' => AppColors.primary,
      _ => AppColors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      task.id,
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
                const SizedBox(height: 6),
                Text(
                  task.title,
                  style: const TextStyle(
                    color: AppColors.textPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.assigneeName,
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
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