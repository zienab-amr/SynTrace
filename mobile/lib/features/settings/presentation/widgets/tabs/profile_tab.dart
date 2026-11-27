import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syntrace/core/cache/cache_scope.dart';
import 'package:syntrace/core/cache/cache_session_guard.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/self_profile_service.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/features/settings/presentation/cubit/settings_cubit.dart';

import 'profile_edit_dialog.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _profileService = SelfProfileService();
  bool _openingEditor = false;

  Future<void> _editProfile() async {
    if (_openingEditor) return;
    final scope = CacheScope.fromCurrentUser();
    if (scope == null) return;

    final guard = CacheSessionGuard.capture(scope);
    setState(() => _openingEditor = true);

    try {
      final details = await _profileService.refresh();
      if (!mounted || !guard.isValid) return;

      final updated = await showDialog<SelfProfileDetails>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ProfileEditDialog(
          details: details,
          guard: guard,
          service: _profileService,
        ),
      );

      if (!mounted || !guard.isValid || updated == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (_) {
      if (!mounted || !guard.isValid) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingEditor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = CurrentUserService.instance;
    final colors = context.appColors;

    return ValueListenableBuilder(
      valueListenable: session.userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const Center(child: Text('Profile unavailable'));
        }

        final name = user.name.trim();
        final parts = name.split(RegExp(r'\s+'));

        final initials = name.isEmpty
            ? '?'
            : parts.length == 1
            ? parts.first[0].toUpperCase()
            : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 32),
          children: [
            _ProfileCard(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.selected,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Name unavailable' : name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user.companyName?.isNotEmpty == true
                                ? user.companyName!
                                : 'Workspace member',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ProfileField(label: 'Full name', value: user.name),
                const SizedBox(height: 18),
                _ProfileField(label: 'Email address', value: user.email),
                const SizedBox(height: 18),
                _ProfileField(
                  label: 'Phone number',
                  value: user.phoneNumber ?? '',
                ),
                const SizedBox(height: 18),
                _ProfileField(
                  label: 'Organization',
                  value: user.companyName ?? '',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileCard(
              children: [
                Text(
                  'Workspace roles',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final role in user.roleNames) Chip(label: Text(role)),
                  ],
                ),
                if (user.roleNames.isEmpty)
                  const Text('No verified roles available.'),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _openingEditor ? null : _editProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _openingEditor
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Edit Profile'),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: Icon(Icons.logout_rounded, color: colors.error, size: 18),
              label: Text('Log out', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access your workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<SettingsCubit>().logout();
    }
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;

  const _ProfileCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            value.trim().isEmpty ? 'Not available' : value,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
