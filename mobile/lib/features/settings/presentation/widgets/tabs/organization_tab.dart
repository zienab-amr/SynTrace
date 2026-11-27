import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/shared/widgets/design_system/design_system.dart';

class OrganizationTab extends StatelessWidget {
  const OrganizationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: CurrentUserService.instance.userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const Center(
            child: Text('Workspace information unavailable.'),
          );
        }

        final isAdmin = user.role == UserRole.admin;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionHeader(
                title: 'Organization',
                subtitle: 'Your connected engineering workspace.',
              ),
              const SizedBox(height: 20),
              _OrganizationCard(user: user),
              const SizedBox(height: 28),
              const AppSectionHeader(
                title: 'Workspace management',
                subtitle: 'Manage your organization and team access.',
              ),
              const SizedBox(height: 16),
              _ManagementTile(
                icon: Icons.people_outline,
                title: 'Team members',
                subtitle: isAdmin
                    ? 'Manage members and workspace access'
                    : 'View your organization members',
                onTap: () {
                  context.push(AppRoutes.developers);
                },
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                _ManagementTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Roles & permissions',
                  subtitle: 'Manage workspace permissions',
                  onTap: () {
                    context.push(AppRoutes.roles);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final UserModel user;

  const _OrganizationCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final companyName = user.companyName?.trim() ?? '';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.business_outlined,
                  size: 28,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR WORKSPACE', style: theme.textTheme.labelSmall),
                    const SizedBox(height: 6),
                    Text(
                      companyName.isNotEmpty
                          ? companyName
                          : 'Organization unavailable',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _DetailRow(label: 'Signed in as', value: user.name),
          const SizedBox(height: 14),
          _DetailRow(label: 'Email', value: user.email),
          const SizedBox(height: 14),
          _DetailRow(label: 'Workspace role', value: user.role.name),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            value.isEmpty ? 'Unavailable' : value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
