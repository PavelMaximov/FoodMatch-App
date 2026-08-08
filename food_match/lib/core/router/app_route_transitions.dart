import 'package:flutter/material.dart';

Widget slideFromRightFadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final Animation<Offset> slideAnimation = Tween<Offset>(
    begin: const Offset(1, 0),
    end: Offset.zero,
  ).animate(curvedAnimation);
  final Animation<double> fadeAnimation = Tween<double>(
    begin: 0.94,
    end: 1,
  ).animate(curvedAnimation);

  return FadeTransition(
    opacity: fadeAnimation,
    child: SlideTransition(position: slideAnimation, child: child),
  );
}
