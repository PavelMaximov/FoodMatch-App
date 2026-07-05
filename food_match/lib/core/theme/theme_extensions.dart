import 'package:flutter/material.dart';

class FoodMatchThemeColors extends ThemeExtension<FoodMatchThemeColors> {
  const FoodMatchThemeColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.primary,
    required this.primaryPressed,
    required this.primarySoft,
    required this.accent,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputFocusedBorder,
    required this.chipBackground,
    required this.chipBorder,
    required this.chipSelectedBorder,
    required this.buttonPrimaryBackground,
    required this.buttonPrimaryText,
    required this.buttonSecondaryBackground,
    required this.buttonSecondaryText,
    required this.bottomNavBackground,
    required this.bottomNavActive,
    required this.bottomNavInactive,
    required this.bottomNavActiveIndicator,
    required this.badgeBackground,
    required this.badgeText,
    required this.dishCardBackground,
    required this.dishCardBorder,
    required this.metadataPillBackground,
    required this.metadataIcon,
    required this.favoriteActive,
    required this.favoriteBtn,
    required this.favoriteInactive,
    required this.modalBackground,
    required this.modalBarrier,
    required this.overlay,
    required this.success,
    required this.warning,
    required this.error,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.imageFallbackBackground,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color cardElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;
  final Color primary;
  final Color primaryPressed;
  final Color primarySoft;
  final Color accent;
  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color inputBackground;
  final Color inputBorder;
  final Color inputFocusedBorder;
  final Color chipBackground;
  final Color chipBorder;
  final Color chipSelectedBorder;
  final Color buttonPrimaryBackground;
  final Color buttonPrimaryText;
  final Color buttonSecondaryBackground;
  final Color buttonSecondaryText;
  final Color bottomNavBackground;
  final Color bottomNavActive;
  final Color bottomNavInactive;
  final Color bottomNavActiveIndicator;
  final Color badgeBackground;
  final Color badgeText;
  final Color dishCardBackground;
  final Color dishCardBorder;
  final Color metadataPillBackground;
  final Color metadataIcon;
  final Color favoriteActive;
  final Color favoriteBtn;
  final Color favoriteInactive;
  final Color modalBackground;
  final Color modalBarrier;
  final Color overlay;
  final Color success;
  final Color warning;
  final Color error;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color imageFallbackBackground;

  @override
  FoodMatchThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
    Color? primary,
    Color? primaryPressed,
    Color? primarySoft,
    Color? accent,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputFocusedBorder,
    Color? chipBackground,
    Color? chipBorder,
    Color? chipSelectedBorder,
    Color? buttonPrimaryBackground,
    Color? buttonPrimaryText,
    Color? buttonSecondaryBackground,
    Color? buttonSecondaryText,
    Color? bottomNavBackground,
    Color? bottomNavActive,
    Color? bottomNavInactive,
    Color? bottomNavActiveIndicator,
    Color? badgeBackground,
    Color? badgeText,
    Color? dishCardBackground,
    Color? dishCardBorder,
    Color? metadataPillBackground,
    Color? metadataIcon,
    Color? favoriteActive,
    Color? favoriteBtn,
    Color? favoriteInactive,
    Color? modalBackground,
    Color? modalBarrier,
    Color? overlay,
    Color? success,
    Color? warning,
    Color? error,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? imageFallbackBackground,
  }) {
    return FoodMatchThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocusedBorder: inputFocusedBorder ?? this.inputFocusedBorder,
      chipBackground: chipBackground ?? this.chipBackground,
      chipBorder: chipBorder ?? this.chipBorder,
      chipSelectedBorder: chipSelectedBorder ?? this.chipSelectedBorder,
      buttonPrimaryBackground: buttonPrimaryBackground ?? this.buttonPrimaryBackground,
      buttonPrimaryText: buttonPrimaryText ?? this.buttonPrimaryText,
      buttonSecondaryBackground: buttonSecondaryBackground ?? this.buttonSecondaryBackground,
      buttonSecondaryText: buttonSecondaryText ?? this.buttonSecondaryText,
      bottomNavBackground: bottomNavBackground ?? this.bottomNavBackground,
      bottomNavActive: bottomNavActive ?? this.bottomNavActive,
      bottomNavInactive: bottomNavInactive ?? this.bottomNavInactive,
      bottomNavActiveIndicator: bottomNavActiveIndicator ?? this.bottomNavActiveIndicator,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeText: badgeText ?? this.badgeText,
      dishCardBackground: dishCardBackground ?? this.dishCardBackground,
      dishCardBorder: dishCardBorder ?? this.dishCardBorder,
      metadataPillBackground: metadataPillBackground ?? this.metadataPillBackground,
      metadataIcon: metadataIcon ?? this.metadataIcon,
      favoriteActive: favoriteActive ?? this.favoriteActive,
      favoriteBtn: favoriteBtn ?? this.favoriteBtn,
      favoriteInactive: favoriteInactive ?? this.favoriteInactive,
      modalBackground: modalBackground ?? this.modalBackground,
      modalBarrier: modalBarrier ?? this.modalBarrier,
      overlay: overlay ?? this.overlay,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      imageFallbackBackground: imageFallbackBackground ?? this.imageFallbackBackground,
    );
  }

  @override
  FoodMatchThemeColors lerp(ThemeExtension<FoodMatchThemeColors>? other, double t) {
    if (other is! FoodMatchThemeColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FoodMatchThemeColors(
      background: l(background, other.background), surface: l(surface, other.surface), card: l(card, other.card), cardElevated: l(cardElevated, other.cardElevated), textPrimary: l(textPrimary, other.textPrimary), textSecondary: l(textSecondary, other.textSecondary), textMuted: l(textMuted, other.textMuted), textInverse: l(textInverse, other.textInverse), primary: l(primary, other.primary), primaryPressed: l(primaryPressed, other.primaryPressed), primarySoft: l(primarySoft, other.primarySoft), accent: l(accent, other.accent), border: l(border, other.border), borderStrong: l(borderStrong, other.borderStrong), divider: l(divider, other.divider), inputBackground: l(inputBackground, other.inputBackground), inputBorder: l(inputBorder, other.inputBorder), inputFocusedBorder: l(inputFocusedBorder, other.inputFocusedBorder), chipBackground: l(chipBackground, other.chipBackground), chipBorder: l(chipBorder, other.chipBorder), chipSelectedBorder: l(chipSelectedBorder, other.chipSelectedBorder), buttonPrimaryBackground: l(buttonPrimaryBackground, other.buttonPrimaryBackground), buttonPrimaryText: l(buttonPrimaryText, other.buttonPrimaryText), buttonSecondaryBackground: l(buttonSecondaryBackground, other.buttonSecondaryBackground), buttonSecondaryText: l(buttonSecondaryText, other.buttonSecondaryText), bottomNavBackground: l(bottomNavBackground, other.bottomNavBackground), bottomNavActive: l(bottomNavActive, other.bottomNavActive), bottomNavInactive: l(bottomNavInactive, other.bottomNavInactive), bottomNavActiveIndicator: l(bottomNavActiveIndicator, other.bottomNavActiveIndicator), badgeBackground: l(badgeBackground, other.badgeBackground), badgeText: l(badgeText, other.badgeText), dishCardBackground: l(dishCardBackground, other.dishCardBackground), dishCardBorder: l(dishCardBorder, other.dishCardBorder), metadataPillBackground: l(metadataPillBackground, other.metadataPillBackground), metadataIcon: l(metadataIcon, other.metadataIcon), favoriteActive: l(favoriteActive, other.favoriteActive), favoriteBtn: l(favoriteBtn, other.favoriteBtn), favoriteInactive: l(favoriteInactive, other.favoriteInactive), modalBackground: l(modalBackground, other.modalBackground), modalBarrier: l(modalBarrier, other.modalBarrier), overlay: l(overlay, other.overlay), success: l(success, other.success), warning: l(warning, other.warning), error: l(error, other.error), shimmerBase: l(shimmerBase, other.shimmerBase), shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight), imageFallbackBackground: l(imageFallbackBackground, other.imageFallbackBackground),
    );
  }
}

extension FoodMatchThemeContext on BuildContext {
  FoodMatchThemeColors get fmColors => Theme.of(this).extension<FoodMatchThemeColors>()!;
}
