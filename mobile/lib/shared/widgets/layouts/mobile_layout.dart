import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/app_bottom_nav.dart';
import 'package:syntrace/shared/widgets/app_mobile_top_bar.dart';

class AppMobileLayout extends StatelessWidget {
  final Widget child;

  const AppMobileLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ─── Top Bar ───
          SafeArea(
            bottom: false,
            child: const AppMobileTopBar(),
          ),

          // ─── Content ───
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}