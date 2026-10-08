import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFF25C00); // YooPN orange
  static const Color primaryDark = Color(0xFFC94A00);
  static const Color primaryLight = Color(0xFFFF8A4C);
  static const Color primaryContainer = Color(0xFFFFE8DB);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF3A1500);

  // Secondary (neutral slate for contrast with the orange)
  static const Color secondary = Color(0xFF1F2937);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Backgrounds and surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF7F7F8);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Borders and dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFEEEEF0);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);

  // VPN connection states
  static const Color connected = success;
  static const Color connecting = warning;
  static const Color disconnected = Color(0xFF9CA3AF);
}