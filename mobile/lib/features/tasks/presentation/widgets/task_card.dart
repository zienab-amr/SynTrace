import 'package:flutter/material.dart';
import 'package:syntrace/features/projects/data/mock_projects.dart';

class TaskCard extends StatelessWidget {
  final MockTaskItem task;
  final VoidCallback? onTap;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final statusColor = _statusColor(task.status);
    final statusLabel = _statusLabel(task.status);
    final priorityColor = _priorityColor(task.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              // ─── Priority Bar ───
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // ─── Content ───
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: ID + Status
                    Row(
                      children: [
                        Text(
                          task.id,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(label: statusLabel, color: statusColor),
                        const Spacer(),
                        _Badge(label: task.priority.toUpperCase(), color: priorityColor),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row 2: Title
                    Text(
                      task.title,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Row 3: Assignee
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12,
                          color: onSurface.withOpacity(0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.assigneeName,
                          style: TextStyle(
                            color: onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'done' => const Color(0xFF10B981),
      'in_progress' => const Color(0xFF3B82F6),
      'blocked' => const Color(0xFFEF4444),
      _ => const Color(0xFF6B7280),
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'done' => 'Done',
      'in_progress' => 'In Progress',
      'blocked' => 'Blocked',
      _ => 'Todo',
    };
  }

  Color _priorityColor(String priority) {
    return switch (priority) {
      'critical' => const Color(0xFFEF4444),
      'high' => const Color(0xFFF59E0B),
      'medium' => const Color(0xFF3B82F6),
      _ => const Color(0xFF6B7280),
    };
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}