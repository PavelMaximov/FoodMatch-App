import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/food_match_ripple.dart';

class SwipeSessionHeader extends StatelessWidget {
  const SwipeSessionHeader({super.key, required this.onSession, required this.onFilters});
  final VoidCallback onSession;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 30, bottom: 17, left: 16, right: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _HeaderAction(label: 'Session', icon: Icons.settings_outlined,
          onTap: onSession, rippleColor: context.fmColors.neutralRipple),
        _HeaderAction(label: 'Filters', icon: Icons.filter_alt_outlined,
          onTap: onFilters, rippleColor: context.fmColors.primaryRipple),
      ],
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.icon, required this.onTap, required this.rippleColor});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color rippleColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    return FoodMatchRipple(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      rippleColor: rippleColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          border: Border.all(color: colors.favoriteBtn),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.nunito(fontSize: 14,
            fontWeight: FontWeight.w700, color: colors.textSecondary)),
        ]),
      ),
    );
  }
}
