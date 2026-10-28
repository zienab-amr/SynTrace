import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════
/// ProjectsTabs
/// 
/// Projects / Tasks / Pull Requests
/// ═══════════════════════════════════════════════════════════
class ProjectsTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const ProjectsTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  static const tabs = ['Projects', 'Tasks', 'Pull Requests'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: List.generate(
            tabs.length,
            (index) => _buildTab(index),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tabs[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : AppColors.textSecondaryDark,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}