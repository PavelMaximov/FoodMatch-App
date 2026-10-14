import 'package:flutter/material.dart';

/// Non-interactive edge accents; the foreground owns all layout and gestures.
class PremiumFoodBackground extends StatelessWidget {
  const PremiumFoodBackground({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final top = MediaQuery.paddingOf(context).top;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final tomatoSize = (width * .23).clamp(70.0, 100.0);
          final bowlSize = (width * .43).clamp(130.0, 190.0);
          final leafSize = (width * .105).clamp(30.0, 50.0);
          final opacity = isDark ? .68 : .38;

          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                // Both food objects end above the hero heading. The tomato
                // peeks around the close control; the bowl shows about a third.
                Positioned(
                  left: -tomatoSize * .46,
                  top: top - tomatoSize * .18,
                  child: _FoodAsset(
                    'tomato',
                    size: tomatoSize,
                    opacity: opacity,
                  ),
                ),
                Positioned(
                  right: -bowlSize * .70,
                  top: top - bowlSize * .62,
                  child: _FoodAsset('bowl', size: bowlSize, opacity: opacity),
                ),
                // Herbs hug the outer edges and the gap above the plan cards.
                Positioned(
                  left: -leafSize * .72,
                  top: constraints.maxHeight * .30,
                  child: Transform.rotate(
                    angle: -.35,
                    child: _FoodAsset(
                      'basil',
                      size: leafSize,
                      opacity: opacity * .7,
                    ),
                  ),
                ),
                Positioned(
                  right: -leafSize * .20,
                  top: constraints.maxHeight * .50,
                  child: Transform.rotate(
                    angle: 2.6,
                    child: _FoodAsset(
                      'basil',
                      size: leafSize,
                      opacity: opacity * .6,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _FoodAsset extends StatelessWidget {
  const _FoodAsset(this.name, {required this.size, required this.opacity});

  final String name;
  final double size, opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: Image.asset(
      'assets/premium/$name.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
