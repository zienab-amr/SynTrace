import 'package:flutter/material.dart';
import 'package:syntrace/core/models/project_model.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ProjectsFilters extends StatelessWidget {
  final ProjectStatus? statusFilter;
  final String? riskFilter;
  final bool hasActiveFilters;
  final ValueChanged<ProjectStatus?> onStatusChanged;
  final ValueChanged<String?> onRiskChanged;
  final VoidCallback onClearAll;

  const ProjectsFilters({
    super.key,
    this.statusFilter,
    this.riskFilter,
    required this.hasActiveFilters,
    required this.onStatusChanged,
    required this.onRiskChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // ─── Status Chips ───
          _FilterChip(
            label: 'All',
            isSelected: statusFilter == null,
            onTap: () => onStatusChanged(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active',
            isSelected: statusFilter == ProjectStatus.active,
            onTap: () => onStatusChanged(ProjectStatus.active),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed',
            isSelected: statusFilter == ProjectStatus.completed,
            onTap: () => onStatusChanged(ProjectStatus.completed),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'On Hold',
            isSelected: statusFilter == ProjectStatus.onHold,
            onTap: () => onStatusChanged(ProjectStatus.onHold),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Archived',
            isSelected: statusFilter == ProjectStatus.archived,
            onTap: () => onStatusChanged(ProjectStatus.archived),
          ),

          // ─── Divider ───
          if (hasActiveFilters) ...[
            const SizedBox(width: 16),
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 16),
            _ClearButton(onTap: onClearAll),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Filter Chip
// ═══════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
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

// ═══════════════════════════════════════════════════════════
// Clear Button
// ═══════════════════════════════════════════════════════════
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