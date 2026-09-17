import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget
{
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = GoRouterState.of(context).uri.path;

    final items = [
      (CupertinoIcons.house, 'Home', AppRoutes.dashboard),
      (CupertinoIcons.chat_bubble, 'Ask', AppRoutes.chat),
      (CupertinoIcons.arrow_branch, 'Graph', AppRoutes.graph),
      (CupertinoIcons.person, 'Profile', AppRoutes.profile),
    ];

    final currentIndex = items
        .indexWhere((i) => i.$3 == currentPath)
        .clamp(0, items.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) => context.go(items[index].$3),
        items: items
            .map((i) => BottomNavigationBarItem(
                  icon: Icon(i.$1),
                  label: i.$2,
                ))
            .toList(),
      ),
    );
  }
}