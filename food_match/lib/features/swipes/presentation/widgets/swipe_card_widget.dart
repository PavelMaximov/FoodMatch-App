import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';

class _SwipeCardPillStyle {
  const _SwipeCardPillStyle({
    required this.background,
    required this.text,
    required this.border,
  });

  final Color background;
  final Color text;
  final Color border;
}

class _SwipeCardInfoStyle {
  const _SwipeCardInfoStyle({
    required this.background,
    required this.icon,
    required this.border,
  });

  final Color background;
  final Color icon;
  final Color border;
}

_SwipeCardPillStyle _pillStyle(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const _SwipeCardPillStyle(
      background: Color.fromRGBO(52, 40, 34, 0.707),
      text: Color(0xFFF0E8E2),
      border: Color.fromRGBO(255, 255, 255, 0.104),
    );
  }

  return const _SwipeCardPillStyle(
    background: Color.fromRGBO(255, 255, 255, 0.697),
    text: Color(0xFF52433E),
    border: Color.fromRGBO(255, 255, 255, 0.50),
  );
}

_SwipeCardInfoStyle _infoStyle(BuildContext context) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const _SwipeCardInfoStyle(
      background: Color.fromRGBO(38, 29, 26, 0.72),
      icon: Color(0xFFF0E8E2),
      border: Color.fromRGBO(255, 255, 255, 0.12),
    );
  }

  return const _SwipeCardInfoStyle(
    background: Color.fromRGBO(255, 255, 255, 0.719),
    icon: Color(0xFF52433E),
    border: Color.fromRGBO(255, 255, 255, 0.40),
  );
}

class SwipeCardWidget extends StatelessWidget {
  const SwipeCardWidget({
    required this.dish,
    this.onLike,
    this.onDislike,
    this.onBack,
    this.onInfoTap,
    this.showSeenBadge = false,
    super.key,
  });

  final Dish dish;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onBack;
  final VoidCallback? onInfoTap;
  final bool showSeenBadge;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final Dish dish = this.dish;
    final String heroImageUrl = ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.swipeCard);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
          Hero(
            tag: 'dish-image-${dish.id}',
            child: SafeDishImage(
              imageUrl: heroImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          if (showSeenBadge)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                ),
                child: Text(
                  'Seen before',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        dish.name,
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildInfoButton(context),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dish.description,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                _buildTags(context),
              ],
            ),
          ),
          if (onBack != null)
            Positioned(
              top: 20,
              right: 20,
              child: _buildPreviousButton(context),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildCircleSvgButton(
                  size: 64,
                  bgColor: const Color(0xFFFFFFFF),
                  assetPath: 'assets/icons/swipe/dislike_swipe.svg',
                  iconColor: colors.error,
                  onTap: onDislike,
                ),
                const SizedBox(width: 32),
                _buildCircleSvgButton(
                  size: 64,
                  bgColor: colors.buttonPrimaryBackground,
                  assetPath: 'assets/icons/swipe/like_swipe.svg',
                  onTap: onLike,
                ),
              ],
            ),
          ),
        ],
        )
      ),
    );
  }

  Widget _buildPreviousButton(BuildContext context) {
    final _SwipeCardInfoStyle infoStyle = _infoStyle(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: infoStyle.background,
          border: Border.all(color: infoStyle.border),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: infoStyle.icon,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildInfoButton(BuildContext context) {
    final _SwipeCardInfoStyle infoStyle = _infoStyle(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInfoTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: infoStyle.background,
          border: Border.all(color: infoStyle.border),
        ),
        child: Icon(
          Icons.info_outline,
          color: infoStyle.icon,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        if (dish.cuisine.isNotEmpty) _buildTag(context, dish.cuisine),
        ...dish.mood.take(3).map((String mood) => _buildTag(context, mood)),
      ],
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final _SwipeCardPillStyle pillStyle = _pillStyle(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: pillStyle.background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        border: Border.all(color: pillStyle.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: pillStyle.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCircleSvgButton({
    required double size,
    required Color bgColor,
    required String assetPath,
    Color iconColor = Colors.white,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: borderColor == null ? null : Border.all(color: borderColor),
          // boxShadow: <BoxShadow>[
          //   BoxShadow(
          //     color: Colors.black.withValues(alpha: 0.15),
          //     blurRadius: 8,
          //     offset: const Offset(0, 2),
          //   ),
          // ],
        ),
        child: Center(
          child: SvgPicture.asset(
            assetPath,
            width: size * 0.30,
            height: size * 0.30,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
