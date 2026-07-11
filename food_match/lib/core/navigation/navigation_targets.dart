import 'package:flutter/material.dart';

class NavigationTargets {
  NavigationTargets._();

  static final GlobalKey matchesTabKey = GlobalKey(debugLabel: 'matchesTab');

  static Rect? matchesTabRect(BuildContext context) {
    final BuildContext? targetContext = matchesTabKey.currentContext;
    final RenderObject? renderObject = targetContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Offset origin = renderObject.localToGlobal(Offset.zero);
      return origin & renderObject.size;
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    const int navItemCount = 5;
    const int matchesIndex = 1;
    final double targetX = screenSize.width * ((matchesIndex + 0.5) / navItemCount);
    final double targetY = screenSize.height - bottomInset - 34;
    return Rect.fromCenter(center: Offset(targetX, targetY), width: 64, height: 64);
  }
}
