import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/layouts/mobile_layout.dart';
import 'package:syntrace/shared/widgets/layouts/web_layout.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return WebLayout(child: child);
    }
    return MobileLayout(child: child);
  }
}