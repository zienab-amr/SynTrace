import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class TaskFilters extends StatelessWidget {
  final String? statusFilter;
  final String? priorityFilter;
  final bool hasActiveFilters;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback onClearAll;

  const TaskFilters({
    super.key,
    this.statusFilter,
    this.priorityFilter,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onClearAll,
  });

  static const _statuses = <(String?, String)>[
    (null, 'All'),
    ('todo', 'Todo'),
    ('in_progress', 'In Progress'),
    ('done', 'Done'),
    ('blocked', 'Blocked'),
  ];

  static const _priorities = <(String?, String)>[
    (null, 'All Priority'),
    ('critical', 'Critical'),
    ('high', 'High'),
    ('medium', 'Medium'),
    ('low', 'Low'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ─── Status Chips ───
          ..._statuses.map((s) {
            final (value, label) = s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: label,
                isSelected: statusFilter == value,
                onTap: () => onStatusChanged(value),
              ),
            );
          }),

          // ─── Priority Chips ───
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: theme.dividerColor,
          ),
          ..._priorities.map((p) {
            final (value, label) = p;
            final color = value != null ? _priorityColor(value) : null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: label,
                isSelected: priorityFilter == value,
                onTap: () => onPriorityChanged(value),
                customColor: color,
              ),
            );
          }),

          // ─── Clear ───
          if (hasActiveFilters) ...[
            const SizedBox(width: 8),
            _ClearButton(onTap: onClearAll),
          ],
        ],
      ),
    );
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? customColor;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = customColor ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : theme.dividerColor.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.close, size: 14, color: AppColors.error),
            SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}