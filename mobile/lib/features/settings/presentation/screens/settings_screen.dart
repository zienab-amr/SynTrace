import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/features/employees/presentation/cubit/employees_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/integrations_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_state.dart';
import 'package:syntrace/features/settings/presentation/widgets/integrations_tab.dart';
import 'package:syntrace/features/settings/presentation/widgets/tabs/organization_tab.dart';
import 'package:syntrace/features/settings/presentation/widgets/tabs/profile_tab.dart';
import 'package:syntrace/shared/widgets/layouts/app_page_scaffold.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTab = 0;

  List<_SettingsTabData> get _tabs {
    final user = CurrentUserService.instance.user;
    final isAdmin = user?.role == UserRole.admin;

    return [
      const _SettingsTabData(icon: Icons.person_outline, label: 'Profile'),
      const _SettingsTabData(icon: Icons.extension_outlined, label: 'Integrations'),
      const _SettingsTabData(icon: Icons.notifications_outlined, label: 'Notifications'),
      const _SettingsTabData(icon: Icons.lock_outline, label: 'Security'),
      if (isAdmin)
        const _SettingsTabData(icon: Icons.business_outlined, label: 'Organization'),
    ];
  }

  @override
  void initState() {
    super.initState();
    context.read<IntegrationsCubit>().loadIntegrations();
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
      child: AppPageScaffold(
        title: 'Settings',
        subtitle: 'Manage your profile, integrations, and preferences',
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabsRow(),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (index) => _buildTab(index)),
      ),
    );
  }

  Widget _buildTab(int index) {
    final theme = Theme.of(context);
    final isSelected = _selectedTab == index;
    final tab = _tabs[index];

    return Padding(
      padding: EdgeInsets.only(right: index == _tabs.length - 1 ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 2,
                  width: isSelected ? 40 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final tabs = _tabs;
    if (_selectedTab >= tabs.length) return const SizedBox.shrink();

    final label = tabs[_selectedTab].label;

    switch (label) {
      case 'Profile':
        return const ProfileTab();
      case 'Integrations':
        return const IntegrationsTab();
      case 'Notifications':
        return const _ComingSoon(title: 'Notifications');
      case 'Security':
        return const _ComingSoon(title: 'Security');
      case 'Organization':
        return BlocProvider(
          create: (context) => EmployeesCubit()..loadEmployees(),
          child: const OrganizationTab(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SettingsTabData {
  final IconData icon;
  final String label;

  const _SettingsTabData({required this.icon, required this.label});
}

class _ComingSoon extends StatelessWidget {
  final String title;

  const _ComingSoon({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '$title — Coming soon',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}