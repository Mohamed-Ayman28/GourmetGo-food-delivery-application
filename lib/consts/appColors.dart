import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // =========================
  // Brand Colors
  // =========================

  /// Primary Orange
  static const Color primary = Color(0xFFFF5F1F);

  static const Color primaryLight = Color(0xFFFF814D);
  static const Color primaryDark = Color(0xFFC54800);

  /// Cream Background
  static const Color secondary = Color(0xFFFFF9F0);

  /// Dark Gray
  static const Color tertiary = Color(0xFF292D32);

  /// Neutral Gray
  static const Color neutral = Color(0xFF707070);

  // =========================
  // Background
  // =========================

  static const Color background = Color(0xFFFFFCF8);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;

  // =========================
  // Text
  // =========================

  static const Color textPrimary = Color(0xFF292D32);
  static const Color textSecondary = Color(0xFF707070);
  static const Color textLight = Color(0xFFA0A0A0);
  static const Color textWhite = Colors.white;

  // =========================
  // Buttons
  // =========================

  static const Color buttonPrimary = primary;
  static const Color buttonSecondary = secondary;
  static const Color buttonText = textWhite;

  static const Color outlinedButton = primary;
  static const Color outlinedButtonText = primary;

  static const Color disabledButton = Color(0xFFD9D9D9);

  // =========================
  // Inputs
  // =========================

  static const Color inputBackground = Colors.white;
  static const Color inputBorder = Color(0xFFE6D7CC);
  static const Color inputFocused = primary;
  static const Color inputHint = Color(0xFFB2B2B2);

  // =========================
  // Borders
  // =========================

  static const Color border = Color(0xFFEAEAEA);
  static const Color divider = Color(0xFFF2F2F2);

  // =========================
  // Icons
  // =========================

  static const Color iconPrimary = tertiary;
  static const Color iconSecondary = neutral;
  static const Color iconActive = primary;
  static const Color iconInactive = Color(0xFF9E9E9E);

  // =========================
  // Status
  // =========================

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  // =========================
  // Misc
  // =========================

  static const Color shadow = Color(0x14000000);
  static const Color overlay = Color(0x55000000);

  static const Color transparent = Colors.transparent;
}