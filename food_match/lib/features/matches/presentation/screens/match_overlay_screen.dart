import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';

class MatchOverlayScreen extends StatefulWidget {
  const MatchOverlayScreen({this.dish, super.key});

  final Dish? dish;

  @override
  State<MatchOverlayScreen> createState() => _MatchOverlayScreenState();
}

class _MatchOverlayScreenState extends State<MatchOverlayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _glowScale;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowOpacity = Tween<double>(begin: 0.20, end: 0.45).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final String? currentUserName = context.watch<AuthProvider>().currentUser?.displayName;
    final String partnerName = _resolvePartnerName(
      members: coupleProvider.currentCouple?.members,
      currentUserName: currentUserName,
    );
    final Size screenSize = MediaQuery.sizeOf(context);
    final double imageWidth = math.min(screenSize.width * 0.68, 300);

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
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - (AppDimensions.paddingM * 2)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        AppStrings.congratulations,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.pacifico(
                          fontSize: math.min(screenSize.width * 0.11, 44),
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
                          fontSize: math.min(screenSize.width * 0.075, 30),
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: math.min(screenSize.height * 0.045, 34)),
                      if (widget.dish != null) ...<Widget>[
                        _GlowingDishImage(
                          dish: widget.dish!,
                          imageWidth: imageWidth,
                          opacityAnimation: _glowOpacity,
                          scaleAnimation: _glowScale,
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
                        SizedBox(height: math.min(screenSize.height * 0.035, 28)),
                      ] else
                        SizedBox(height: math.min(screenSize.height * 0.035, 28)),
                      _MatchInfoPanel(partnerName: partnerName),
                      const SizedBox(height: AppDimensions.paddingL),
                      _MatchOverlayButton(
                        text: AppStrings.continueBrowsing,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(height: AppDimensions.paddingM - 4),
                      _MatchOverlayButton(
                        text: AppStrings.goToMatchResults,
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF211B20),
                        onPressed: () {
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

  String _resolvePartnerName({List<String>? members, String? currentUserName}) {
    if (members == null || members.isEmpty) {
      return AppStrings.yourPartner;
    }

    for (final String member in members) {
      if (member.isNotEmpty && member != currentUserName) {
        return member;
      }
    }

    return AppStrings.yourPartner;
  }
}

class _GlowingDishImage extends StatelessWidget {
  const _GlowingDishImage({
    required this.dish,
    required this.imageWidth,
    required this.opacityAnimation,
    required this.scaleAnimation,
  });

  final Dish dish;
  final double imageWidth;
  final Animation<double> opacityAnimation;
  final Animation<double> scaleAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: imageWidth,
      height: imageWidth + 28,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            bottom: 8,
            child: AnimatedBuilder(
              animation: opacityAnimation,
              builder: (_, __) => Transform.scale(
                scale: scaleAnimation.value,
                child: Container(
                  width: imageWidth * 0.82,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: opacityAnimation.value),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.white.withValues(alpha: opacityAnimation.value),
                        blurRadius: 36,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                  width: imageWidth,
                  height: imageWidth,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: imageWidth,
                    height: imageWidth,
                    color: const Color(0xFFF1EFEE),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchInfoPanel extends StatelessWidget {
  const _MatchInfoPanel({required this.partnerName});

  final String partnerName;

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
      height: AppDimensions.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
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
