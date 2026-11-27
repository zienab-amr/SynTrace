import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand ──────────────────────────────

  static const Color primary = Color(0xFF243D60);
  static const Color primaryDark = Color(0xFF172B47);
  static const Color primaryLight = Color(0xFFA0BCE5);

  static const Color actionLight = primary;
  static const Color actionDark = primaryLight;

  static const Color secondary = Color(0xFF52758A);
  static const Color secondaryDark = Color(0xFF365B70);
  static const Color secondaryLight = Color(0xFF9CBFCF);

  // ─── Porcelain & Ink ────────────────────

  static const Color backgroundLight = Color(0xFFF5F3EF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFEDEBE6);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);

  static const Color textPrimaryLight = Color(0xFF172333);
  static const Color textSecondaryLight = Color(0xFF697787);
  static const Color textMutedLight = Color(0xFF697787);

  static const Color borderLight = Color(0xFFDFE1DF);
  static const Color borderStrongLight = Color(0xFFC5CBD1);

  static const Color selectedLight = Color(0xFFE5EBF3);

  // ─── Black Sapphire ─────────────────────

  static const Color backgroundDark = Color(0xFF090D13);
  static const Color surfaceDark = Color(0xFF121A26);
  static const Color surfaceMutedDark = Color(0xFF182231);
  static const Color surfaceElevatedDark = Color(0xFF1C2838);

  static const Color textPrimaryDark = Color(0xFFF1F4F9);
  static const Color textSecondaryDark = Color(0xFF8998AD);
  static const Color textMutedDark = Color(0xFF8998AD);

  static const Color borderDark = Color(0xFF253448);
  static const Color borderStrongDark = Color(0xFF3A4D65);

  static const Color selectedDark = Color(0xFF22334B);

  // ─── Semantic ───────────────────────────

  static const Color success = Color(0xFF258269);
  static const Color warning = Color(0xFFB5833D);
  static const Color error = Color(0xFFC45B5B);
  static const Color info = Color(0xFF527DA8);

  static const Color successLightForeground = Color(0xFF17654F);
  static const Color warningLightForeground = Color(0xFF865B24);
  static const Color errorLightForeground = Color(0xFFA63838);

  static const Color successDarkForeground = Color(0xFF80CDB1);
  static const Color warningDarkForeground = Color(0xFFE4BD80);
  static const Color errorDarkForeground = Color(0xFFF0A0A0);

  static const Color successSurfaceLight = Color(0xFFE6F2EC);
  static const Color warningSurfaceLight = Color(0xFFF6EEDF);
  static const Color errorSurfaceLight = Color(0xFFF8E9E9);
  static const Color infoSurfaceLight = Color(0xFFE7EDF5);

  static const Color successSurfaceDark = Color(0xFF142D28);
  static const Color warningSurfaceDark = Color(0xFF30281E);
  static const Color errorSurfaceDark = Color(0xFF342329);
  static const Color infoSurfaceDark = Color(0xFF1B2D43);

  // ─── Compatibility ──────────────────────

  static const Color textMuted = textMutedLight;
  static const Color divider = borderDark;
  static const Color border = borderDark;
  static const Color disabled = Color(0xFF7D8794);
}
