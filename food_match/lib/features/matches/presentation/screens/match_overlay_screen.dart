import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';

class MatchOverlayScreen extends StatelessWidget {
  const MatchOverlayScreen({this.dish, super.key});

  final Dish? dish;

  @override
  Widget build(BuildContext context) {
    final String dishName = (dish?.name.trim().isNotEmpty ?? false)
        ? dish!.name.trim()
        : 'this dish';
    final String? imageUrl = dish == null
        ? null
        : ImageUtils.getImageUrl(
            dish!.imageUrl,
            usage: ImageUsage.matchOverlay,
          );
    final bool useCustomPlaceholder = dish?.isCustom == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (useCustomPlaceholder ||
              (imageUrl != null && imageUrl.trim().isNotEmpty))
            SafeDishImage(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              emptyImageAsset: useCustomPlaceholder
                  ? AppEmptyStateAssets.customDishPlaceholder
                  : null,
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF3A2420), Color(0xFF141016)],
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.66)),
          ),
          IgnorePointer(
            child: Lottie.asset(
              'assets/animations/confetti_transparent.json',
              fit: BoxFit.cover,
              repeat: false,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 56, 30, 32),
              child: Column(
                children: <Widget>[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'It\'s a match!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        fontSize: 53,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'You both liked',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dishName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  _MatchOverlayButton(
                    text: 'Continue swiping',
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  _MatchOverlayButton(
                    text: 'View match results',
                    backgroundColor: Colors.white.withValues(alpha: 0.94),
                    foregroundColor: const Color(0xFF211B20),
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/matches');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchOverlayButton extends StatelessWidget {
  const _MatchOverlayButton({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String text;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w900, color: foregroundColor),
        ),
      ),
    );
  }
}
