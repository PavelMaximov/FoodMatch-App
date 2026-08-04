import 'package:flutter/material.dart';

enum FoodMatchNotificationType { success, destructive, warning, error, info }

@immutable
class FoodMatchNotificationColors {
  const FoodMatchNotificationColors({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconBackground,
    required this.actionColor,
    required this.titleColor,
    required this.subtitleColor,
    required this.trailingDotColor,
  });

  final Color background;
  final Color border;
  final Color icon;
  final Color iconBackground;
  final Color actionColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color trailingDotColor;

  static FoodMatchNotificationColors lerp(
    FoodMatchNotificationColors a,
    FoodMatchNotificationColors b,
    double t,
  ) => FoodMatchNotificationColors(
    background: Color.lerp(a.background, b.background, t)!,
    border: Color.lerp(a.border, b.border, t)!,
    icon: Color.lerp(a.icon, b.icon, t)!,
    iconBackground: Color.lerp(a.iconBackground, b.iconBackground, t)!,
    actionColor: Color.lerp(a.actionColor, b.actionColor, t)!,
    titleColor: Color.lerp(a.titleColor, b.titleColor, t)!,
    subtitleColor: Color.lerp(a.subtitleColor, b.subtitleColor, t)!,
    trailingDotColor: Color.lerp(a.trailingDotColor, b.trailingDotColor, t)!,
  );
}

class FoodMatchNotificationTheme
    extends ThemeExtension<FoodMatchNotificationTheme> {
  const FoodMatchNotificationTheme({
    required this.success,
    required this.destructive,
    required this.warning,
    required this.error,
  });

  final FoodMatchNotificationColors success;
  final FoodMatchNotificationColors destructive;
  final FoodMatchNotificationColors warning;
  final FoodMatchNotificationColors error;

  FoodMatchNotificationColors colorsFor(FoodMatchNotificationType type) =>
      switch (type) {
        FoodMatchNotificationType.success => success,
        FoodMatchNotificationType.destructive => destructive,
        FoodMatchNotificationType.warning ||
        FoodMatchNotificationType.info => warning,
        FoodMatchNotificationType.error => error,
      };

  @override
  FoodMatchNotificationTheme copyWith({
    FoodMatchNotificationColors? success,
    FoodMatchNotificationColors? destructive,
    FoodMatchNotificationColors? warning,
    FoodMatchNotificationColors? error,
  }) => FoodMatchNotificationTheme(
    success: success ?? this.success,
    destructive: destructive ?? this.destructive,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  FoodMatchNotificationTheme lerp(
    covariant ThemeExtension<FoodMatchNotificationTheme>? other,
    double t,
  ) {
    if (other is! FoodMatchNotificationTheme) return this;
    return FoodMatchNotificationTheme(
      success: FoodMatchNotificationColors.lerp(success, other.success, t),
      destructive: FoodMatchNotificationColors.lerp(
        destructive,
        other.destructive,
        t,
      ),
      warning: FoodMatchNotificationColors.lerp(warning, other.warning, t),
      error: FoodMatchNotificationColors.lerp(error, other.error, t),
    );
  }
}
