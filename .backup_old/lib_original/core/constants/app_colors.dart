import 'package:flutter/material.dart';

/// Bảng màu chuẩn Material 3 cho DocuShare
class AppColors {
  AppColors._();

  // Primary & Secondary Brand Colors
  static const Color primary = Color(0xFF1E40AF); // Blue 800
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF172554); // Blue 950

  static const Color secondary = Color(0xFF0D9488); // Teal 600
  static const Color secondaryLight = Color(0xFF14B8A6); // Teal 500

  static const Color tertiary = Color(0xFF7C3AED); // Purple 600

  // Status Colors
  static const Color success = Color(0xFF16A34A); // Green 600
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color info = Color(0xFF0284C7); // Sky 600

  // Neutral Colors (Light Theme)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9); // Slate 100
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF475569); // Slate 600
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  // Neutral Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF0B1120);
  static const Color surfaceDark = Color(0xFF151E32);
  static const Color surfaceVariantDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
}
