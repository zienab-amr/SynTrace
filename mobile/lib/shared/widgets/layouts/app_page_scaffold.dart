import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:syntrace/core/router/routes.dart';
import 'package:syntrace/core/theme/app_icons.dart';
import 'package:syntrace/core/theme/app_spacing.dart';
import 'package:syntrace/core/theme/app_text_styles.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';

class AppPageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? searchBar;
  final Widget? filterBar;
  final Widget child;
  final bool scrollable;
  final bool showBackButton;
  final double maxContentWidth;
  final EdgeInsets? contentPadding;
  final VoidCallback? onBack;

  const AppPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.searchBar,
    this.filterBar,
    required this.child,
    this.scrollable = false,
    this.showBackButton = false,
    this.maxContentWidth = 1400,
    this.contentPadding,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final horizontalPadding = isMobile
                ? AppSpacing.mobilePage
                : AppSpacing.desktopPage;

            final padding =
                contentPadding ??
                EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  isMobile ? AppSpacing.lg : AppSpacing.xxl,
                );

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageHeader(
                      title: title,
                      subtitle: subtitle,
                      actions: actions ?? const [],
                      showBackButton: showBackButton,
                      onBack: onBack,
                      isMobile: isMobile,
                      horizontalPadding: horizontalPadding,
                    ),

                    if (searchBar != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          AppSpacing.md,
                        ),
                        child: searchBar!,
                      ),

                    if (filterBar != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          isMobile ? AppSpacing.sm : AppSpacing.lg,
                        ),
                        child: filterBar!,
                      ),

                    Expanded(
                      child: scrollable
                          ? SingleChildScrollView(
                              padding: padding,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: child,
                            )
                          : Padding(padding: padding, child: child),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBackButton;
  final bool isMobile;
  final double horizontalPadding;
  final VoidCallback? onBack;

  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.showBackButton,
    required this.isMobile,
    required this.horizontalPadding,
    this.onBack,
  });

  bool get _hasInlineActions =>
      actions.isNotEmpty &&
      actions.length <= 2 &&
      actions.every((action) => action is IconButton);

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }

    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.projects);
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = subtitle?.trim();

    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton)
          IconButton(
            tooltip: 'Go back',
            onPressed: () => _handleBack(context),
            icon: const Icon(AppIcons.back, size: 20),
          ),

        Expanded(
          child: Text(
            title,
            style: (isMobile ? AppTextStyles.mobilePageTitle : AppTextStyles.h1)
                .copyWith(color: context.appColors.textPrimary),
          ),
        ),

        if (isMobile && _hasInlineActions) ...[
          const SizedBox(width: AppSpacing.xs),
          ...actions,
        ],
      ],
    );

    final actionGroup = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,

        if (description != null && description.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              left: showBackButton ? 48 : 0,
              top: AppSpacing.xs,
            ),
            child: Text(
              description,
              style: context.appText.bodyMedium?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isMobile ? AppSpacing.mobileHeaderTop : AppSpacing.xxl,
        horizontalPadding,
        isMobile ? AppSpacing.mobileHeaderBottom : AppSpacing.xl,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,

                if (actions.isNotEmpty && !_hasInlineActions) ...[
                  const SizedBox(height: AppSpacing.sm),
                  actionGroup,
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),

                if (actions.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(child: actionGroup),
                ],
              ],
            ),
    );
  }
}
