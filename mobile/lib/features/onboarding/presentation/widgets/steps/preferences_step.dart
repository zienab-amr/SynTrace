import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/theme_controller.dart';

class PreferencesStep extends StatelessWidget {
  final bool isDarkMode;
  final bool notificationsEnabled;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<bool> onNotificationsChanged;

  const PreferencesStep({
    super.key,
    required this.isDarkMode,
    required this.notificationsEnabled,
    required this.onDarkModeChanged,
    required this.onNotificationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalize your workspace',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how SynTrace looks on your device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              return Column(
                children: [
                  _ThemeOption(
                    icon: Icons.light_mode_outlined,
                    title: 'Light',
                    subtitle: 'A bright and clean workspace',
                    selected: mode == ThemeMode.light,
                    onTap: () => onDarkModeChanged(false),
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark',
                    subtitle: 'A comfortable low-light experience',
                    selected: mode == ThemeMode.dark,
                    onTap: () => onDarkModeChanged(true),
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    icon: Icons.settings_brightness_outlined,
                    title: 'System',
                    subtitle: 'Follow your device appearance',
                    selected: mode == ThemeMode.system,
                    onTap: () {
                      ThemeController.setTheme(ThemeMode.system);
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'You can change your appearance anytime in Settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? scheme.primary : theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
