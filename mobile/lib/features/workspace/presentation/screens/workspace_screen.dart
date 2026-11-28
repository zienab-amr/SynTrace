import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/features/workspace/presentation/widgets/workspace_menu_item.dart';
import 'package:syntrace/features/workspace/presentation/widgets/workspace_menu_section.dart';
import 'package:syntrace/shared/widgets/design_system/app_card.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';
import 'package:syntrace/shared/widgets/user_avatar.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        final isAdmin = user?.isAdmin ?? false;

        return AppPageScaffold(
          title: 'Workspace',
          subtitle: 'Manage your engineering workspace',
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                _WorkspaceIdentity(user: user),
                const SizedBox(height: AppSpacing.sectionGap),
              ],

              WorkspaceMenuSection(
                title: 'Collaboration',
                children: [
                  WorkspaceMenuItem(
                    icon: AppIcons.employees,
                    title: 'Team members',
                    subtitle: 'Explore your engineering team',
                    onTap: () => context.push(AppRoutes.developers),
                  ),
                  WorkspaceMenuItem(
                    icon: AppIcons.tasks,
                    title: 'Tasks',
                    subtitle: 'Track assigned work',
                    onTap: () => context.push(AppRoutes.tasks),
                  ),
                  WorkspaceMenuItem(
                    icon: AppIcons.meetings,
                    title: 'Meetings',
                    subtitle: 'Decisions and meeting notes',
                    onTap: () => context.push(AppRoutes.meetings),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sectionGap),

              WorkspaceMenuSection(
                title: 'Workspace management',
                children: [
                  if (isAdmin)
                    WorkspaceMenuItem(
                      icon: AppIcons.permissions,
                      title: 'Roles & permissions',
                      subtitle: 'Manage workspace access',
                      onTap: () => context.push(AppRoutes.roles),
                    ),
                  WorkspaceMenuItem(
                    icon: AppIcons.activity,
                    title: 'Activity',
                    subtitle: 'Review Jira activity',
                    onTap: () => context.push(AppRoutes.jiraActivity),
                  ),
                  WorkspaceMenuItem(
                    icon: AppIcons.settings,
                    title: 'Settings',
                    subtitle: 'Manage your preferences',
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceIdentity extends StatelessWidget {
  final UserModel user;

  const _WorkspaceIdentity({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AppCard(
      onTap: () => context.push(AppRoutes.profile),
      child: Row(
        children: [
          UserAvatar(user: user, size: 46),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: context.appText.titleMedium),
                if (user.companyName?.trim().isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user.companyName!,
                    style: context.appText.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appText.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const Icon(AppIcons.chevronRight, size: 18),
        ],
      ),
    );
  }
}
