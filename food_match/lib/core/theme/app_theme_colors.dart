import 'package:flutter/material.dart';

import 'theme_extensions.dart';

class AppThemeColors {
  const AppThemeColors._();

  static const FoodMatchThemeColors light = FoodMatchThemeColors(
    background: Color(0xFFFFFBF9), surface: Color(0xFFFFFFFF), card: Color(0xFFFFFFFF), cardElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1A), textSecondary: Color(0xFF505050), textMuted: Color(0xFF7A7270), textInverse: Color(0xFFFFFFFF),
    primary: Color(0xFFFF5B1C), primaryPressed: Color(0xFFE04A10), primarySoft: Color(0xFFFFEFE7), accent: Color(0xFFFD5115),
    border: Color(0xFFE8E0DC), borderStrong: Color(0xFFBFB7B2), divider: Color(0xFFE8E0DC),
    inputBackground: Color(0xFFFFFFFF), inputBorder: Color(0xFFE8E0DC), inputFocusedBorder: Color(0xFFFF5B1C),
    chipBackground: Color(0xFFF5EDE8), chipBorder: Color(0xFFE8E0DC), chipSelectedBorder: Color(0xFFFF5B1C),
    buttonPrimaryBackground: Color(0xFFFF5B1C), buttonPrimaryText: Color(0xFFFFFFFF), buttonSecondaryBackground: Color(0xFFFFFFFF), buttonSecondaryText: Color(0xFF1A1A1A),
    bottomNavBackground: Color(0xFFFFFBF9), bottomNavActive: Color(0xFF5D4136), bottomNavInactive: Color(0xFF52433E), bottomNavActiveIndicator: Color(0xFFFFDCD0), badgeBackground: Color(0xFFFD5115), badgeText: Color(0xFFFFFFFF),
    dishCardBackground: Color(0xFFFFFFFF), dishCardBorder: Color(0xFFE5E5E5), metadataPillBackground: Color(0xFFFFFFFF), metadataIcon: Color(0xFFFF5B1C), favoriteActive: Color(0xFFFF5D33), favoriteInactive: Color(0xFF505050), favoriteBtn: Color(0xFFDCD6D3),
    modalBackground: Color(0xFFFFFFFF), modalBarrier: Color(0x8C000000), overlay: Color(0x8C000000),
    success: Color(0xFF43A047), warning: Color(0xFFEE8C04), error: Color(0xFFE53935),
    shimmerBase: Color(0xFFE0E0E0), shimmerHighlight: Color(0xFFF5F5F5), imageFallbackBackground: Color(0xFFF5EDE8),
    primaryRipple: Color(0x38FF7043), likeRipple: Color(0x335CCB8A), dislikeRipple: Color(0x2EFF6B6B), undoRipple: Color(0x38F2B66D), neutralRipple: Color(0x248A6F63), navRipple: Color(0x29FF7043),
  );

  static const FoodMatchThemeColors dark = FoodMatchThemeColors(
    background: Color(0xFF17110F), surface: Color(0xFF211917), card: Color(0xFF261D1A), cardElevated: Color(0xFF2D221F),
    textPrimary: Color(0xFFFFF4EE), textSecondary: Color(0xFFD8C9C1), textMuted: Color(0xFFA99B94), textInverse: Color(0xFF1A100D),
    primary: Color(0xFFFF7043), primaryPressed: Color(0xFFE85A2A), primarySoft: Color(0xFF4A2418), accent: Color(0xFFFF6A2A),
    border: Color(0xFF3A2D29), borderStrong: Color(0xFF5A4740), divider: Color(0xFF352923),
    inputBackground: Color.fromARGB(255, 40, 30, 27), inputBorder: Color(0xFF4A3933), inputFocusedBorder: Color(0xFFFF7043),
    chipBackground: Color(0xFF30231F), chipBorder: Color(0xFF493832), chipSelectedBorder: Color(0xFFFF7043),
    buttonPrimaryBackground: Color(0xFFFF7043), buttonPrimaryText: Color(0xFFFFFFFF), buttonSecondaryBackground: Color(0xFF2A201D), buttonSecondaryText: Color(0xFFFFF4EE),
    bottomNavBackground: Color(0xFF17110F), bottomNavActive: Color(0xFFFFB199), bottomNavInactive: Color(0xFFB8A9A1), bottomNavActiveIndicator: Color(0xFF4A2418), badgeBackground: Color(0xFFFF6A2A), badgeText: Color(0xFFFFFFFF),
    dishCardBackground: Color(0xFF261D1A), dishCardBorder: Color(0xFF3D302B), metadataPillBackground: Color(0xFF342822), metadataIcon: Color(0xFFFF8A5C), favoriteActive: Color(0xFFFF6A4A), favoriteBtn: Color(0xFF4C4746), favoriteInactive: Color(0xFFB8A9A1),
    modalBackground: Color(0xFF211917), modalBarrier: Color(0xA6000000), overlay: Color(0x8C000000),
    success: Color(0xFF66D28A), warning: Color(0xFFFFB84D), error: Color(0xFFFF6B64),
    shimmerBase: Color(0xFF2A211E), shimmerHighlight: Color(0xFF3A2E29), imageFallbackBackground: Color(0xFF2A201D),
    primaryRipple: Color(0x42FF8A65), likeRipple: Color(0x3D72D79B), dislikeRipple: Color(0x38FF7A7A), undoRipple: Color(0x3DFFC878), neutralRipple: Color(0x24F2C6A0), navRipple: Color(0x33FF8A65),
  );
}
