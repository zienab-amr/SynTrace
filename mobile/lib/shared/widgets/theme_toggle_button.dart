import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/theme_controller.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return PopupMenuButton<ThemeMode>(
          tooltip: 'Change Theme',
          icon: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
          ),
          onSelected: (selectedMode) {
            ThemeController.setTheme(selectedMode);
          },
          itemBuilder: (context) => [
            _buildItem(context, ThemeMode.system, mode, Icons.brightness_auto, 'System'),
            _buildItem(context, ThemeMode.light, mode, Icons.light_mode, 'Light'),
            _buildItem(context, ThemeMode.dark, mode, Icons.dark_mode, 'Dark'),
          ],
        );
      },
    );
  }

  PopupMenuItem<ThemeMode> _buildItem(
    BuildContext context,
    ThemeMode mode,
    ThemeMode current,
    IconData icon,
    String label,
  ) {
    final isSelected = mode == current;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isSelected ? primaryColor : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            Icon(Icons.check, size: 18, color: primaryColor),
          ],
        ],
      ),
    );
  }
}