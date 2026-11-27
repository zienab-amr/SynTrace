import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_theme_extension.dart';
import 'package:syntrace/shared/widgets/app_bottom_nav.dart';
import 'package:syntrace/shared/widgets/app_mobile_top_bar.dart';

class AppMobileLayout extends StatelessWidget {
  final Widget child;

  const AppMobileLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          ColoredBox(
            color: colors.surface,
            child: const SafeArea(bottom: false, child: AppMobileTopBar()),
          ),

          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: child,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}
