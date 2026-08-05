import 'package:flutter/material.dart';

const Duration kSlideUpFadeTransitionDuration = Duration(milliseconds: 400);

Widget slideUpFadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<double> curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic,
  );
  final Animation<Offset> offset = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(curved);

  return FadeTransition(
    opacity: curved,
    child: SlideTransition(position: offset, child: child),
  );
}
