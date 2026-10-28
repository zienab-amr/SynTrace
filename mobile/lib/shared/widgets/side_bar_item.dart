import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isCollapsed;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isActive = currentPath == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? AppColors.primary.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondaryDark,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.textPrimaryDark
                            : AppColors.textSecondaryDark,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}