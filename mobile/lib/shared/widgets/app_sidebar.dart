import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_colors.dart';
import 'package:syntrace/shared/widgets/logo_mark.dart';
import 'package:syntrace/shared/widgets/side_bar_item.dart';

class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
{
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _isCollapsed ? 72 : 200,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                const LogoMark(),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SynTrace',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 1),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: AppRoutes.dashboard,
                  isCollapsed: _isCollapsed,
                ),
                SidebarItem(
                  icon: CupertinoIcons.chat_bubble,
                  label: 'AI Chat',
                  route: AppRoutes.chat,
                  isCollapsed: _isCollapsed,
                ),
                SidebarItem(
                  icon: Icons.hub_outlined,
                  label: 'Knowledge Graph',
                  route: AppRoutes.graph,
                  isCollapsed: _isCollapsed,
                ),
                 SidebarItem(
                  icon: Icons.folder_outlined,
                  label: 'Projects',
                  route: AppRoutes.projects,
                   isCollapsed: _isCollapsed,
                  ),
                SidebarItem(
                      icon: Icons.task_alt,
                      label: 'Tasks',
                      route: AppRoutes.tasks,
                      isCollapsed: _isCollapsed,
                  ),
                SidebarItem(
                  icon: CupertinoIcons.settings,
                  label: 'Settings',
                  route: AppRoutes.settings, 
                  isCollapsed: _isCollapsed,
                ),
        ],
            ),
          ),

          // Toggle button
          Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton(
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              icon: Icon(
                _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: AppColors.textSecondaryDark,
              ),
              tooltip: _isCollapsed ? 'Expand' : 'Collapse',
            ),
          ),
        ],
      ),
    );
  }
}