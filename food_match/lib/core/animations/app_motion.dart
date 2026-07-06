import 'package:flutter/material.dart';

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration tab = Duration(milliseconds: 420);
  static const Duration indicatorScale = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;

  static Duration durationFor(BuildContext context, Duration duration) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations || mediaQuery.accessibleNavigation) {
      return const Duration(milliseconds: 1);
    }
    return duration;
  }
}
