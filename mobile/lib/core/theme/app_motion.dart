import 'package:flutter/material.dart';

class AppMotion {
  AppMotion._();

  static const Duration instant = Duration(milliseconds: 100);

  static const Duration fast = Duration(milliseconds: 160);

  static const Duration standard = Duration(milliseconds: 240);

  static const Duration slow = Duration(milliseconds: 360);

  static const Duration reveal = Duration(milliseconds: 650);

  static const Duration brandReveal = Duration(milliseconds: 1200);

  static const Curve enter = Curves.easeOutCubic;

  static const Curve exit = Curves.easeInCubic;

  static const Curve standardCurve = Curves.easeInOutCubic;

  static Duration resolve(BuildContext context, Duration duration) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return reduceMotion ? Duration.zero : duration;
  }
}
