import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/theme_toggle_button.dart';

class AppTopBar extends StatelessWidget
{
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search Bar
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 12),
                  Icon(Icons.search, color: AppColors.textSecondaryDark, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Search',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
           const ThemeToggleButton(),
    
           const SizedBox(width: 8),
          // Notifications
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text('A', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}