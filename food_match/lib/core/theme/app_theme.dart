import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_text_styles.dart';
import 'app_theme_colors.dart';
import 'theme_extensions.dart';
import 'notification_theme_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light, AppThemeColors.light);

  static ThemeData get dark => _build(Brightness.dark, AppThemeColors.dark);

  static ThemeData _build(Brightness brightness, FoodMatchThemeColors colors) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme = isDark
        ? ColorScheme.dark(
            primary: colors.primary,
            secondary: colors.primarySoft,
            surface: colors.surface,
            error: colors.error,
            onPrimary: colors.buttonPrimaryText,
            onSurface: colors.textPrimary,
            onSurfaceVariant: colors.textSecondary,
            outline: colors.border,
          )
        : ColorScheme.light(
            primary: colors.primary,
            secondary: colors.primarySoft,
            surface: colors.surface,
            error: colors.error,
            onPrimary: colors.buttonPrimaryText,
            onSurface: colors.textPrimary,
            onSurfaceVariant: colors.textSecondary,
            outline: colors.border,
          );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.divider,
      cardColor: colors.card,
      extensions: <ThemeExtension<dynamic>>[
        colors,
        isDark
            ? AppNotificationThemeColors.dark
            : AppNotificationThemeColors.light,
      ],
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        titleTextStyle: AppTextStyles.sectionHeader.copyWith(
          color: colors.textPrimary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.modalBackground,
        modalBackgroundColor: colors.modalBackground,
        modalBarrierColor: colors.modalBarrier,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.modalBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.cardTitle.copyWith(
          color: colors.textPrimary,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.cardElevated,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textMuted),
        filled: true,
        fillColor: colors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.inputFocusedBorder, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          backgroundColor: colors.buttonPrimaryBackground,
          foregroundColor: colors.buttonPrimaryText,
          disabledBackgroundColor: colors.buttonPrimaryBackground.withValues(
            alpha: 0.45,
          ),
          disabledForegroundColor: colors.buttonPrimaryText.withValues(
            alpha: 0.65,
          ),
          elevation: 0,
          textStyle: AppTextStyles.button.copyWith(
            color: colors.buttonPrimaryText,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
          side: BorderSide(color: colors.border),
          foregroundColor: colors.primary,
          textStyle: AppTextStyles.button.copyWith(color: colors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.chipBackground,
        selectedColor: colors.primarySoft,
        disabledColor: colors.chipBackground.withValues(alpha: 0.5),
        labelStyle: AppTextStyles.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        secondaryLabelStyle: AppTextStyles.bodySmall.copyWith(
          color: colors.primary,
        ),
        side: BorderSide(color: colors.chipBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTextStyles.logoTitle.copyWith(color: colors.primary),
        headlineMedium: AppTextStyles.screenHeader.copyWith(
          color: colors.textPrimary,
        ),
        headlineSmall: AppTextStyles.sectionHeader.copyWith(
          color: colors.textPrimary,
        ),
        titleMedium: AppTextStyles.cardTitle.copyWith(
          color: colors.textPrimary,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: colors.textPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: colors.textSecondary,
        ),
        bodySmall: AppTextStyles.bodySmall.copyWith(
          color: colors.textSecondary,
        ),
        labelLarge: AppTextStyles.button.copyWith(
          color: colors.buttonPrimaryText,
        ),
      ),
    );
  }
}
