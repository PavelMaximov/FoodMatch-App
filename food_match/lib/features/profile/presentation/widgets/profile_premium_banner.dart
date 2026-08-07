import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/assets/app_profile_assets.dart';
import '../../../../core/widgets/food_match_ripple.dart';

class ProfilePremiumBanner extends StatelessWidget {
  const ProfilePremiumBanner({required this.onTap, super.key});

  static const double _height = 60;
  static const double _radius = 20;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark
        ? const Color(0xFFFFF8F1)
        : const Color(0xFF191514);
    final String backgroundAsset = isDark
        ? AppProfileAssets.premiumBannerDark
        : AppProfileAssets.premiumBannerLight;

    return FoodMatchRipple(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_radius),
      rippleColor: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.black.withValues(alpha: 0.10),
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const <Color>[Color(0xFF614A4D), Color(0xFF4A436C)]
                        : const <Color>[Color(0xFFEFC56D), Color(0xFFE99B72)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              Image.asset(
                backgroundAsset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Image.asset(
                      AppProfileAssets.premiumCrownIcon,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => _CrownFallback(
                        color: titleColor,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Upgrade to Premium',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 28,
                      color: titleColor.withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrownFallback extends StatelessWidget {
  const _CrownFallback({required this.color, required this.backgroundColor});

  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(Icons.workspace_premium_rounded, color: color, size: 26),
    );
  }
}
