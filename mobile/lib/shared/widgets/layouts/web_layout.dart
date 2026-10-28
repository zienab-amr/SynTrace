import 'package:flutter/material.dart';
import 'package:syntrace/shared/widgets/app_sidebar.dart';
import 'package:syntrace/shared/widgets/app_top_bar.dart';


class WebLayout extends StatelessWidget
{
  final Widget  child;

   const WebLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(),
          Expanded(
            child: Column(
              children: [
                const AppTopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}