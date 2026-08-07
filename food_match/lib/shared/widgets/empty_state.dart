import 'package:flutter/material.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/food_match_empty_state_image.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    this.icon,
    this.imageAsset,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    super.key,
  });

  final IconData? icon;
  final String? imageAsset;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (imageAsset != null)
              FoodMatchEmptyStateImage(
                assetPath: imageAsset!,
                width: 200,
                height: 180,
                fallback: icon == null
                    ? null
                    : Icon(icon, size: 80, color: colors.textMuted),
              )
            else if (icon != null)
              Icon(icon, size: 80, color: colors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...<Widget>[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
