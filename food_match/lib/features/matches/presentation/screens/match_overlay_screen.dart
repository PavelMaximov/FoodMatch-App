import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/couple.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';

class MatchOverlayScreen extends StatefulWidget {
  const MatchOverlayScreen({this.dish, super.key});

  final Dish? dish;

  @override
  State<MatchOverlayScreen> createState() => _MatchOverlayScreenState();
}

class _MatchOverlayScreenState extends State<MatchOverlayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final String? currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final String partnerName = resolvePartnerDisplayName(
      couple: coupleProvider.currentCouple,
      currentUserId: currentUserId,
      fallback: AppStrings.yourPartner,
    );
    final Size screenSize = MediaQuery.sizeOf(context);
    final double imageWidth = math.min(screenSize.width * 0.68, 300.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[
              Color(0xFF614A4D),
              Color(0xFF4A436C),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingL,
                  vertical: AppDimensions.paddingM,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (AppDimensions.paddingM * 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        AppStrings.congratulations,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.pacifico(
                          fontSize: math.min(screenSize.width * 0.11, 44.0).toDouble(),
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.paddingXS),
                      Text(
                        'You have a Match!',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: math.min(screenSize.width * 0.075, 30.0).toDouble(),
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: math.min(screenSize.height * 0.045, 34.0).toDouble()),
                      if (widget.dish != null) ...<Widget>[
                        _GlowingDishImage(
                          dish: widget.dish!,
                          imageWidth: imageWidth,
                          animation: _glowController,
                        ),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(
                          widget.dish!.name.isEmpty ? 'Untitled dish' : widget.dish!.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: math.min(screenSize.height * 0.035, 28.0).toDouble()),
                      ] else
                        SizedBox(height: math.min(screenSize.height * 0.035, 28.0).toDouble()),
                      _MatchInfoPanel(
                        partnerName: partnerName,
                        onContinueBrowsing: () => Navigator.pop(context),
                        onGoToMatches: () {
                          Navigator.pop(context);
                          context.go('/matches');
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Glowing dish image with sweep border animation ───────────────────────────

class _GlowingDishImage extends StatelessWidget {
  const _GlowingDishImage({
    required this.dish,
    required this.imageWidth,
    required this.animation,
  });

  final Dish dish;
  final double imageWidth;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final double t = Curves.easeInOut.transform(animation.value);
        return Container(
          width: imageWidth,
          height: imageWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              // Внутренний слой — резкий, брендовый цвет
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45 + t * 0.25),
                blurRadius: 12 + t * 10,
                spreadRadius: 1 + t * 3,
              ),
              // Внешний слой — широкий мягкий ореол
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15 + t * 0.15),
                blurRadius: 28 + t * 20,
                spreadRadius: 4 + t * 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SafeNetworkImage(
              imageUrl: ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.dishHero),
              width: imageWidth,
              height: imageWidth,
              fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }
}



 

// ── Match info panel ─────────────────────────────────────────────────────────

class _MatchInfoPanel extends StatelessWidget {
  const _MatchInfoPanel({
    required this.partnerName,
    required this.onContinueBrowsing,
    required this.onGoToMatches,
  });

  final String partnerName;
  final VoidCallback onContinueBrowsing;
  final VoidCallback onGoToMatches;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '${AppStrings.youAnd} $partnerName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            AppStrings.chosenSameDish.replaceAll('.', ''),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          Text(
            AppStrings.nowYouHaveChoice,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingL),
          _MatchOverlayButton(
            text: AppStrings.continueBrowsing,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: onContinueBrowsing,
          ),
          const SizedBox(height: AppDimensions.paddingM - 4),
          _MatchOverlayButton(
            text: AppStrings.goToMatchResults,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF211B20),
            onPressed: onGoToMatches,
          ),
        ],
      ),
    );
  }
}

// ── Button ───────────────────────────────────────────────────────────────────

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
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.button.copyWith(color: foregroundColor),
        ),
      ),
    );
  }
}