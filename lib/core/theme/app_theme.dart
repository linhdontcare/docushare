// ==============================================================================
// CORE LAYER: App Theme (Hệ thống Theme "Deep Tech Emerald" - LDC Edition)
// Thiết kế theo yêu cầu nhận diện thương hiệu:
// - Scaffold Background: Deep Slate Navy (#0F172A)
// - Card Background: Dark Slate (#1E293B) với BorderRadius.circular(16)
// - Primary Accent: Emerald Green (#10B981) cho FAB, Active Tabs, Icons
// - Text Colors: Pure White (#FFFFFF) & Muted Slate (#94A3B8)
// - Hiệu ứng Gradient: LinearGradient cho AppBar & Header Cards tạo chiều sâu công nghệ
// ==============================================================================

import 'package:flutter/material.dart';

class AppTheme {
  // Bảng màu nhận diện đặc trưng "Deep Tech Emerald"
  static const Color primaryColor = Color(0xFF10B981); // Emerald Green #10B981
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400
  static const Color primaryDark = Color(0xFF059669); // Emerald 600

  static const Color scaffoldBackground = Color(0xFF0F172A); // Deep Slate Navy #0F172A
  static const Color cardBackground = Color(0xFF1E293B); // Dark Slate #1E293B
  static const Color borderSubtle = Color(0xFF334155); // Slate 700

  static const Color textPrimary = Color(0xFFFFFFFF); // Pure White #FFFFFF
  static const Color textSecondary = Color(0xFF94A3B8); // Muted Slate #94A3B8

  // Các hiệu ứng Gradient tạo chiều sâu (Depth Effect)
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B), // Dark Slate
      Color(0xFF0F172A), // Deep Slate Navy
    ],
  );

  static const LinearGradient emeraldPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981), // Emerald 500
      Color(0xFF059669), // Emerald 600
    ],
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF243248),
      Color(0xFF1E293B),
    ],
  );

  // Theme chính của ứng dụng (Deep Tech Emerald)
  static ThemeData get deepTechEmeraldTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: cardBackground,
        primary: primaryColor,
        secondary: primaryLight,
        onSurface: textPrimary,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: primaryColor),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBackground,
        selectedColor: primaryColor.withValues(alpha: 0.2),
        secondarySelectedColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  // Tương thích ngược: lightTheme và darkTheme đều sử dụng Deep Tech Emerald
  static ThemeData get lightTheme => deepTechEmeraldTheme;
  static ThemeData get darkTheme => deepTechEmeraldTheme;
}
