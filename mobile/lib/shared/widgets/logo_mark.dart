import 'package:flutter/material.dart';

class LogoMark extends StatelessWidget {
  final double size;

  const LogoMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icons/icon_dark.png',
        fit: BoxFit.contain,
        color: isDark ? null : null, 
      ),
    );
  }
}