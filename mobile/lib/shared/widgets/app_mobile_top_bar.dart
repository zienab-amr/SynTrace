import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';
import 'package:syntrace/shared/widgets/user_avatar.dart';

/// ═══════════════════════════════════════════════════════════
/// AppMobileTopBar
/// 
/// Top Bar للموبايل — بيظهر فوق كل الشاشات
/// ═══════════════════════════════════════════════════════════
class AppMobileTopBar extends StatelessWidget {
  const AppMobileTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ─── Logo ───
          const LogoMark(size: 32),
          const SizedBox(width: 10),
          const Text(
            'SynTrace',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const Spacer(),

          // ─── Search ───
          IconButton(
            onPressed: () => _onSearchTap(context),
            icon: Icon(
              Icons.search,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              size: 22,
            ),
            tooltip: 'Search',
          ),

          // ─── Notifications ───
          Stack(
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.notifications),
                icon: Icon(
                  Icons.notifications_outlined,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  size: 22,
                ),
                tooltip: 'Notifications',
              ),
              // ─── Red Dot ───
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),

          // ─── Avatar ───
          ValueListenableBuilder<UserModel?>(
            valueListenable: CurrentUserService.instance.userNotifier,
            builder: (context, user, _) {
              return UserAvatar(
                user: user,
                size: 32,
                onTap: () => context.go(AppRoutes.profile),
              );
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // Search Tap
  // ═══════════════════════════════════════════════════════
  void _onSearchTap(BuildContext context) {
    showSearch(
      context: context,
      delegate: _MobileSearchDelegate(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Search Delegate بسيط
// ═══════════════════════════════════════════════════════════
class _MobileSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Center(
      child: Text(
        'Search results for: $query',
        style: const TextStyle(color: AppColors.textPrimaryDark),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Search projects, developers, PRs, bugs...',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
      ),
    );
  }
}