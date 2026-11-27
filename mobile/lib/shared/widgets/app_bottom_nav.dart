import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_motion.dart';
import 'package:syntrace/core/theme/app_premium_icons.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

import 'app_icon.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _destinations = [
    _NavigationDestination(
      icon: AppPremiumIcons.home,
      label: 'Home',
      path: AppRoutes.dashboard,
    ),
    _NavigationDestination(
      icon: AppPremiumIcons.projects,
      label: 'Projects',
      path: AppRoutes.projects,
    ),
    _NavigationDestination(
      icon: AppPremiumIcons.chat,
      label: 'Chat',
      path: AppRoutes.chat,
    ),
    _NavigationDestination(
      icon: AppPremiumIcons.graph,
      label: 'Graph',
      path: AppRoutes.graph,
    ),
    _NavigationDestination(
      icon: AppPremiumIcons.workspace,
      label: 'More',
      path: AppRoutes.workspace,
    ),
  ];

  int _selectedIndex(String path) {
    for (var index = 0; index < _destinations.length; index++) {
      final destination = _destinations[index];

      if (path == destination.path || path.startsWith('${destination.path}/')) {
        return index;
      }
    }

    return _destinations.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: colors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                children: List.generate(_destinations.length, (index) {
                  final destination = _destinations[index];

                  return Expanded(
                    child: _NavigationItem(
                      destination: destination,
                      selected: index == selectedIndex,
                      onTap: () {
                        if (path != destination.path) {
                          context.go(destination.path);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestination {
  final AppIconData icon;
  final String label;
  final String path;

  const _NavigationDestination({
    required this.icon,
    required this.label,
    required this.path,
  });
}

class _NavigationItem extends StatelessWidget {
  final _NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final foreground = selected ? scheme.primary : colors.textSecondary;

    final duration = AppMotion.resolve(context, AppMotion.fast);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: duration,
                curve: AppMotion.enter,
                height: 2,
                width: selected ? 20 : 0,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      destination.icon,
                      size: 24,
                      color: foreground,
                      strokeWidth: selected ? 1.9 : 1.65,
                    ),

                    const SizedBox(height: 5),

                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: AppMotion.enter,
                      style: (context.appText.labelSmall ?? const TextStyle())
                          .copyWith(
                            fontSize: 10,
                            height: 1.3,
                            letterSpacing: 0.1,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: foreground,
                          ),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
