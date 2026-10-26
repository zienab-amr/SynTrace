import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/shared/widgets/theme_toggle_button.dart';
import 'package:syntrace/shared/widgets/user_avatar.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          const Spacer(),
          const ThemeToggleButton(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_outlined,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<UserModel?>(
            valueListenable: CurrentUserService.instance.userNotifier,
            builder: (context, user, _) {
              return UserAvatar(
                user: user,
                size: 36,
                onTap: () => context.go(AppRoutes.profile),
              );
            },
          ),
        ],
      ),
    );
  }
}