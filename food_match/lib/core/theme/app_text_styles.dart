import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  // Logo title
  static TextStyle get logoTitle => GoogleFonts.fredoka(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );

  // Page headers and auth screen titles.
  static TextStyle get pageTitle => GoogleFonts.fredoka(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // Screen headers (Login, Sign Up, Forgot password?, etc.)
  static TextStyle get screenHeader => pageTitle;

  // Section headers (Ingredients, Cooking)
  static TextStyle get sectionHeader => GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // Body
  static TextStyle get bodyLarge => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySmall => GoogleFonts.nunito(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // Button text
  static TextStyle get button => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  // Card title
  static TextStyle get cardTitle => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // Match congratulations
  static TextStyle get matchCongrats => GoogleFonts.fredoka(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );
}
