import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppPageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? searchBar;
  final Widget? filterBar;
  final Widget child;
  final bool scrollable;
  final bool showBackButton;   // ← جديد
  final double maxContentWidth;
  final EdgeInsets? contentPadding;

  const AppPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.searchBar,
    this.filterBar,
    required this.child,
    this.scrollable = false,
    this.showBackButton = false,   // ← جديد
    this.maxContentWidth = 1400,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, isMobile),
                if (searchBar != null) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                    ),
                    child: searchBar!,
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],
                if (filterBar != null) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 32,
                    ),
                    child: filterBar!,
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],
                Expanded(
                  child: scrollable
                      ? SingleChildScrollView(
                          padding: contentPadding ??
                              EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 32,
                              ),
                          child: child,
                        )
                      : Padding(
                          padding: contentPadding ??
                              EdgeInsets.symmetric(
                                horizontal: isMobile ? 16 : 32,
                              ),
                          child: child,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 16,
        isMobile ? 16 : 24,
        isMobile ? 16 : 32,
        isMobile ? 12 : 16,
      ),
      child: Row(
        children: [
          // ─── Back Button ───
          if (showBackButton)
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/projects');
                }
              },
              icon: Icon(
                Icons.arrow_back,
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (showBackButton) SizedBox(width: isMobile ? 0 : 8),

          // ─── Title ───
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ─── Actions ───
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 12),
            ...actions!,
          ],
        ],
      ),
    );
  }
}