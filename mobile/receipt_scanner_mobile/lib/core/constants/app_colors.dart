import 'package:flutter/material.dart';

/// App color constants for consistent theming
class AppColors {
  AppColors._();

  /// Primary green - rgba(72, 199, 116, 1)
  static const Color primaryGreen = Color(0xFF48C774);

  /// Secondary green - rgba(171, 222, 188, 1)
  static const Color secondaryGreen = Color(0xFFABDEBC);

  /// Light green background
  static Color get greenBackground => primaryGreen.withOpacity(0.15);

  /// Error/Warning colors
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  /// Neutral colors
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F9F5);
}
