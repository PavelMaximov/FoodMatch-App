import 'package:flutter/material.dart';

import 'notification_theme.dart';

class AppNotificationThemeColors {
  const AppNotificationThemeColors._();

  static const FoodMatchNotificationTheme light = FoodMatchNotificationTheme(
    success: FoodMatchNotificationColors(
      background: Color(0xFFE4F0E8),
      border: Color(0xFF85D9A1),
      icon: Color(0xFF3A8A5A),
      iconBackground: Color(0xFFD2E7D9),
      actionColor: Color(0xFF3A8A5A),
      titleColor: Color(0xFF1A1A1A),
      subtitleColor: Color(0xFF505050),
      trailingDotColor: Color(0xFF3A8A5A),
    ),
    destructive: FoodMatchNotificationColors(
      background: Color(0xFFFDEEE6),
      border: Color(0xFFDDA794),
      icon: Color(0xFFE85A2A),
      iconBackground: Color(0xFFF8DCD0),
      actionColor: Color(0xFFE85A2A),
      titleColor: Color(0xFF1A1A1A),
      subtitleColor: Color(0xFF505050),
      trailingDotColor: Color(0xFFE85A2A),
    ),
    warning: FoodMatchNotificationColors(
      background: Color(0xFFFDF0DC),
      border: Color(0xFFD3BE9A),
      icon: Color(0xFFB5780A),
      iconBackground: Color(0xFFF3E1BF),
      actionColor: Color(0xFFB5780A),
      titleColor: Color(0xFF1A1A1A),
      subtitleColor: Color(0xFF505050),
      trailingDotColor: Color(0xFFB5780A),
    ),
    error: FoodMatchNotificationColors(
      background: Color(0xFFFDE7E6),
      border: Color(0xFFDDA794),
      icon: Color(0xFFE8342A),
      iconBackground: Color(0xFFF7D4D2),
      actionColor: Color(0xFFE8342A),
      titleColor: Color(0xFF1A1A1A),
      subtitleColor: Color(0xFF505050),
      trailingDotColor: Color(0xFFE8342A),
    ),
  );

  static const FoodMatchNotificationTheme dark = FoodMatchNotificationTheme(
    success: FoodMatchNotificationColors(
      background: Color(0xFF1A3020),
      border: Color(0xFF298353),
      icon: Color(0xFF60B17D),
      iconBackground: Color(0xFF1C4F34),
      actionColor: Color(0xFF60B17D),
      titleColor: Color(0xFFFFF4EE),
      subtitleColor: Color(0xFFD8C9C1),
      trailingDotColor: Color(0xFF60B17D),
    ),
    destructive: FoodMatchNotificationColors(
      background: Color(0xFF3A1A10),
      border: Color(0xFF703429),
      icon: Color(0xFFBC4A23),
      iconBackground: Color(0xFF483431),
      actionColor: Color(0xFFBC4A23),
      titleColor: Color(0xFFFFF4EE),
      subtitleColor: Color(0xFFD8C9C1),
      trailingDotColor: Color(0xFFBC4A23),
    ),
    warning: FoodMatchNotificationColors(
      background: Color(0xFF2E2208),
      border: Color(0xFF886B36),
      icon: Color.fromARGB(255, 112, 88, 41),
      iconBackground: Color(0xFF6F5D3C),
      actionColor: Color(0xFFD8B56D),
      titleColor: Color(0xFFFFF4EE),
      subtitleColor: Color(0xFFD8C9C1),
      trailingDotColor: Color(0xFF886B36),
    ),
    error: FoodMatchNotificationColors(
      background: Color(0xFF3A1010),
      border: Color(0xFF702929),
      icon: Color(0xFFBC2B23),
      iconBackground: Color(0xFF483131),
      actionColor: Color(0xFFE05B54),
      titleColor: Color(0xFFFFF4EE),
      subtitleColor: Color(0xFFD8C9C1),
      trailingDotColor: Color(0xFFBC2B23),
    ),
  );
}
