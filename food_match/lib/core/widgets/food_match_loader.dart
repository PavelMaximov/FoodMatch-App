import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/theme_extensions.dart';

class FoodMatchLoader extends StatelessWidget {
  const FoodMatchLoader({
    super.key,
    this.size = 72,
    this.label,
    this.dimmed = false,
  });

  final double size;
  final String? label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        dimmed ? Colors.white : context.fmColors.textPrimary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/animations/waiting.json',
            repeat: true,
            animate: true,
            fit: BoxFit.contain,
          ),
        ),
        if (label != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            label!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ],
    );
  }
}
