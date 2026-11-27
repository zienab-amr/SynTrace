import 'package:flutter/material.dart';

import '../../data/models/project_api_model.dart';

class ProjectStatusFilter extends StatelessWidget {
  final ProjectApiStatus? selectedStatus;
  final ValueChanged<ProjectApiStatus?> onChanged;

  const ProjectStatusFilter({
    super.key,
    required this.selectedStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = ProjectApiStatus.values.where(
      (status) => status != ProjectApiStatus.unknown,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            context,
            label: 'All projects',
            selected: selectedStatus == null,
            onTap: () => onChanged(null),
          ),
          for (final status in statuses) ...[
            const SizedBox(width: 8),
            _buildChip(
              context,
              label: status.label,
              selected: selectedStatus == status,
              onTap: () => onChanged(status),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primaryContainer,
      backgroundColor: scheme.surface,
      side: BorderSide(
        color: selected
            ? scheme.primary.withValues(alpha: 0.35)
            : scheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
