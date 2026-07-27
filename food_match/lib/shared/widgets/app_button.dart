import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/food_match_ripple.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool darkBackground;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.darkBackground = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    if (isOutlined) {
      final Color outlinedColor = darkBackground
          ? colors.textInverse
          : colors.primary;
      return FoodMatchRipple(
        onTap: isLoading ? null : onPressed,
        enabled: !isLoading && onPressed != null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        rippleColor: colors.neutralRipple,
        child: IgnorePointer(
          child: SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: OutlinedButton(
              onPressed: isLoading || onPressed == null ? null : () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: darkBackground ? colors.textInverse : colors.border,
                ),
                foregroundColor: outlinedColor,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusButton,
                  ),
                ),
              ),
              child: _buildChild(
                colors,
                isOutlined: true,
                outlinedColor: outlinedColor,
              ),
            ),
          ),
        ),
      );
    }

    return FoodMatchRipple(
      onTap: isLoading ? null : onPressed,
      enabled: !isLoading && onPressed != null,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      rippleColor: colors.primaryRipple,
      child: IgnorePointer(
        child: SizedBox(
          width: double.infinity,
          height: AppDimensions.buttonHeight,
          child: ElevatedButton(
            onPressed: isLoading || onPressed == null ? null : () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.buttonPrimaryBackground,
              foregroundColor: colors.buttonPrimaryText,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            child: _buildChild(colors),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(
    FoodMatchThemeColors colors, {
    bool isOutlined = false,
    Color? outlinedColor,
  }) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isOutlined
              ? (outlinedColor ?? colors.primary)
              : colors.buttonPrimaryText,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: isOutlined
                ? AppTextStyles.button.copyWith(
                    color: outlinedColor ?? colors.primary,
                  )
                : AppTextStyles.button.copyWith(
                    color: colors.buttonPrimaryText,
                  ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: isOutlined
          ? AppTextStyles.button.copyWith(
              color: outlinedColor ?? colors.primary,
            )
          : AppTextStyles.button.copyWith(color: colors.buttonPrimaryText),
    );
  }
}
