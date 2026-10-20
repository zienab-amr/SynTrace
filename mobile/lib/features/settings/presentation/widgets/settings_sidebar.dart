import 'package:flutter/material.dart';

class SettingsSidebar extends StatelessWidget
{
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const SettingsSidebar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const items = [
    (Icons.person_outline, 'Profile'),
    (Icons.extension_outlined, 'Integrations'),
    (Icons.notifications_outlined, 'Notifications'),
    (Icons.lock_outline, 'Security'),
    (Icons.business_outlined, 'Organization'),
  ];

  @override
  Widget build(BuildContext context)
  {
    final theme = Theme.of(context);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: List.generate(items.length, (index) {
          final (icon, label) = items[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onTabSelected(index),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}