import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';

class SwipeCardWidget extends StatelessWidget {
  const SwipeCardWidget({
    required this.dish,
    this.onLike,
    this.onDislike,
    this.onBack,
    this.onRefresh,
    this.onConnectSession,
    this.connectedCount = 0,
    super.key,
  });

  final Dish dish;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onConnectSession;
  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Hero(
            tag: 'dish-image-${dish.id}',
            child: CachedNetworkImage(
              imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GestureDetector(
                  onTap: onConnectSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    ),
                    child: Text(
                      'Connect session',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                  ),
                  child: Text(
                    'Connected $connectedCount/2',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
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
                    Colors.black.withOpacity(0.8),
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
                        dish.title,
                        style: GoogleFonts.nunito(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dish.description,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.85),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    if (dish.cuisine.isNotEmpty) _buildTag(dish.cuisine),
                    ...dish.tags.take(3).map(_buildTag),
                  ],
                ),
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
                  bgColor: Colors.white.withOpacity(0.15),
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
                  bgColor: Colors.white.withOpacity(0.15),
                  icon: Icons.refresh,
                  iconColor: Colors.white,
                  onTap: onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
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
              color: Colors.black.withOpacity(0.15),
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
