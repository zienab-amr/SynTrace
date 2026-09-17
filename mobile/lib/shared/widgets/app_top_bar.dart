import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/theme_toggle_button.dart';

class AppTopBar extends StatelessWidget {
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
          // ─── Search Bar ───
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
                  Icon(
                    Icons.search,
                    color: AppColors.textSecondaryDark,
                    size: 20,
                  ),
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

          // ─── Theme Toggle ───
          const ThemeToggleButton(),
          const SizedBox(width: 8),

          // ─── Notifications ───
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(width: 8),

          // ─── User Avatar ───
          const _UserAvatar(),
        ],
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════
/// User Avatar
/// 
class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        // ─── لو مفيش مستخدم، اعرض Placeholder ───
        final initials = user?.initials ?? '?';
        final avatarUrl = user?.avatarUrl;

        return Tooltip(
          message: user?.name ?? 'Guest',
          child: InkWell(
            onTap: () => context.go(AppRoutes.profile),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                backgroundImage:
                    avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}