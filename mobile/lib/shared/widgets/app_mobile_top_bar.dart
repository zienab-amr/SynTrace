import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import 'app_icon_button.dart';
import 'logo_mark.dart';
import 'user_avatar.dart';

class AppMobileTopBar extends StatefulWidget {
  const AppMobileTopBar({super.key});

  @override
  State<AppMobileTopBar> createState() => _AppMobileTopBarState();
}

class _AppMobileTopBarState extends State<AppMobileTopBar> {
  bool _isNavigating = false;

  Future<void> _openPage(String path) async {
    if (_isNavigating || !mounted) return;

    final currentPath = GoRouterState.of(context).uri.path;

    if (currentPath == path) return;

    setState(() => _isNavigating = true);

    try {
      await context.push<void>(path);
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final path = GoRouterState.of(context).uri.path;

    final isActivity = path == AppRoutes.jiraActivity;

    final isSettings = path == AppRoutes.settings;

    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 20, right: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.8)),
      ),
      child: Row(
        children: [
          const LogoMark(size: 29),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              'SynTrace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appText.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                color: colors.textPrimary,
              ),
            ),
          ),

          AppIconButton(
            icon: AppPremiumIcons.activity,
            tooltip: 'Activity',
            selected: isActivity,
            iconSize: 23,
            onPressed: _isNavigating || isActivity
                ? null
                : () => _openPage(AppRoutes.jiraActivity),
          ),

          const SizedBox(width: 2),

          _ProfileAction(
            enabled: !_isNavigating && !isSettings,
            onTap: () => _openPage(AppRoutes.settings),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ProfileAction({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        return Tooltip(
          message: 'Account settings',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled && user != null ? onTap : null,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderStrong, width: 0.8),
                  ),
                  child: UserAvatar(user: user, size: 30),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
