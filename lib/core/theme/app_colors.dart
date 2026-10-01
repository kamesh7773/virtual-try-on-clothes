import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color secondary = Color(0xFF06B6D4);
  static const Color accent = Color(0xFFF59E0B);

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textHint = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // ─── Try-on surfaces ───────────────────────────────────────────────
  // The try-on experience is dark: a bright UI reflects off the screen and
  // washes out the camera feed it sits next to. Ported from the web app's
  // black/neutral palette.
  static const Color stageBackground = Color(0xFF000000);
  static const Color stageSurface = Color(0xFF0A0A0A);
  static const Color stageElevated = Color(0xFF171717);
  static const Color stageBorder = Color(0x1AFFFFFF);
  static const Color stageBorderActive = Color(0x66FFFFFF);

  static const Color onStagePrimary = Color(0xFFFFFFFF);
  static const Color onStageSecondary = Color(0xB3FFFFFF);
  static const Color onStageMuted = Color(0x80FFFFFF);
  static const Color onStageFaint = Color(0x4DFFFFFF);

  static const Color live = Color(0xFF4ADE80);

  // ─── Style Me (Dick's) ─────────────────────────────────────────────
  // The kiosk flow's own palette, taken from the web mirror it replaces.
  static const Color styleTeal = Color(0xFF16E0C9);

  /// Text on a teal fill.
  static const Color styleOnTeal = Color(0xFF05231C);
  static const Color styleStage = Color(0xFF091714);
  static const Color styleCard = Color(0xFF0C1A15);
  static const Color styleDeepGreen = Color(0xFF006554);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);
}
