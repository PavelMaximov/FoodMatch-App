import 'package:flutter/material.dart';

/// Note: upstream web source code is unavailable in this environment
/// (missing submodule URL), so these values are a close MVP approximation.
class AppTheme {
  static const Color primary = Color(0xFFFF6B35);
  static const Color secondary = Color(0xFF4ECDC4);
  static const Color accent = Color(0xFFFFE66D);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF52606D);
  static const double borderRadiusM = 16;

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusM),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: textPrimary,
        ),
        bodyMedium: const TextStyle(
          color: textSecondary,
        ),
      ),
    );
  }
}
