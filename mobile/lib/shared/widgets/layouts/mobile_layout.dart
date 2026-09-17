import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/app_bottom_nav.dart';

class MobileLayout extends StatelessWidget
{
  final Widget child;

  const MobileLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}