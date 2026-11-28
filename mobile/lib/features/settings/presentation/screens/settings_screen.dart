import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_radius.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/jira/jira_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/github/github_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_state.dart';
import 'package:syntrace/features/settings/presentation/widgets/integrations_tab.dart';
import 'package:syntrace/features/settings/presentation/widgets/tabs/appearance_tab.dart';
import 'package:syntrace/features/settings/presentation/widgets/tabs/organization_tab.dart';
import 'package:syntrace/features/settings/presentation/widgets/tabs/profile_tab.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

enum _SettingsSection {
  profile,
  appearance,
  integrations,
  notifications,
  security,
  organization,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsSection _selectedSection = _SettingsSection.profile;

  List<_SettingsTabData> _tabs(UserModel? user) {
    return [
      const _SettingsTabData(
        section: _SettingsSection.profile,
        icon: AppIcons.profile,
        label: 'Profile',
      ),
      const _SettingsTabData(
        section: _SettingsSection.appearance,
        icon: AppIcons.sun,
        label: 'Appearance',
      ),
      const _SettingsTabData(
        section: _SettingsSection.integrations,
        icon: AppIcons.integrations,
        label: 'Integrations',
      ),
      const _SettingsTabData(
        section: _SettingsSection.notifications,
        icon: AppIcons.notifications,
        label: 'Notifications',
      ),
      const _SettingsTabData(
        section: _SettingsSection.security,
        icon: AppIcons.security,
        label: 'Security',
      ),
      if (user?.isAdmin ?? false)
        const _SettingsTabData(
          section: _SettingsSection.organization,
          icon: AppIcons.organization,
          label: 'Organization',
        ),
    ];
  }

  @override
  void initState() {
    super.initState();

    context.read<JiraCubit>().loadIntegrations();
    context.read<GitHubCubit>().loadIntegrations();
    context.read<SettingsCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoggedOut) {
          context.go(AppRoutes.login);
        }
      },
      child: ValueListenableBuilder<UserModel?>(
        valueListenable: CurrentUserService.instance.userNotifier,
        builder: (context, user, _) {
          final tabs = _tabs(user);

          final selected = tabs.any((tab) => tab.section == _selectedSection)
              ? _selectedSection
              : _SettingsSection.profile;

          return AppPageScaffold(
            title: 'Settings',
            subtitle: 'Manage your account and workspace',
            scrollable: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsTabs(
                  tabs: tabs,
                  selected: selected,
                  onSelected: (section) {
                    setState(() {
                      _selectedSection = section;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.xl),

                Expanded(child: _buildContent(selected)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.profile:
        return const ProfileTab();

      case _SettingsSection.appearance:
        return const AppearanceTab();

      case _SettingsSection.integrations:
        return const IntegrationsTab();

      case _SettingsSection.notifications:
        return const _ComingSoon(title: 'Notifications');

      case _SettingsSection.security:
        return const _ComingSoon(title: 'Security');

      case _SettingsSection.organization:
        return BlocProvider(
          create: (context) => EmployeesCubit()..loadEmployees(),
          child: const OrganizationTab(),
        );
    }
  }
}

class _SettingsTabs extends StatelessWidget {
  final List<_SettingsTabData> tabs;
  final _SettingsSection selected;
  final ValueChanged<_SettingsSection> onSelected;

  const _SettingsTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _SettingsTabButton(
                tab: tab,
                selected: selected == tab.section,
                onTap: () => onSelected(tab.section),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  final _SettingsTabData tab;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;

    final foreground = selected ? primary : colors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.selected : Colors.transparent,
        borderRadius: AppRadius.medium,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.medium,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 18, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    tab.label,
                    style: context.appText.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTabData {
  final _SettingsSection section;
  final IconData icon;
  final String label;

  const _SettingsTabData({
    required this.section,
    required this.icon,
    required this.label,
  });
}

class _ComingSoon extends StatelessWidget {
  final String title;

  const _ComingSoon({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.settings, size: 40, color: colors.textSecondary),

            const SizedBox(height: AppSpacing.lg),

            Text(
              '$title — Coming soon',
              style: context.appText.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
