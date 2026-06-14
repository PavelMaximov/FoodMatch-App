import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';

class SwipeCardWidget extends StatelessWidget {
  const SwipeCardWidget({
    required this.dish,
    this.onLike,
    this.onDislike,
    this.onBack,
    this.onRefresh,
    this.onInfoTap,
    this.showSeenBadge = false,
    super.key,
  });

  final Dish dish;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onInfoTap;
  final bool showSeenBadge;


  @override
  Widget build(BuildContext context) {
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
              right: 16,
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
                    _buildInfoButton(),
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
                _buildTags(),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildCircleButton(
                  size: 44,
                  bgColor: Colors.white.withValues(alpha: 0.15),
                  icon: Icons.chevron_left,
                  iconColor: Colors.white,
                  onTap: onBack,
                ),
                _buildCircleButton(
                  size: 56,
                  bgColor: Colors.white,
                  icon: Icons.close,
                  iconColor: AppColors.textPrimary,
                  onTap: onDislike,
                ),
                _buildCircleButton(
                  size: 64,
                  bgColor: AppColors.primary,
                  icon: Icons.restaurant,
                  iconColor: Colors.white,
                  onTap: onLike,
                ),
                _buildCircleButton(
                  size: 44,
                  bgColor: Colors.white.withValues(alpha: 0.15),
                  icon: Icons.refresh,
                  iconColor: Colors.white,
                  onTap: onRefresh,
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildInfoButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInfoTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        if (dish.cuisine.isNotEmpty) _buildTag(dish.cuisine),
        ...dish.mood.take(3).map(_buildTag),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required double size,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
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
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}
