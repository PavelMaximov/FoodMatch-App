import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:food_match/core/theme/app_colors.dart';
import 'package:food_match/core/theme/app_dimensions.dart';
import 'package:food_match/core/utils/image_utils.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:google_fonts/google_fonts.dart';

enum RecipeDishCardLayout { horizontal, grid }

class RecipeDishCard extends StatelessWidget {
  const RecipeDishCard({
    super.key,
    required this.dish,
    required this.isSaved,
    required this.onFavoriteTap,
    required this.onOpen,
    required this.layout,
    this.favoriteAlignment = Alignment.topRight,
    this.isFavoriteUpdating = false,
    this.cardBorderColor = const Color(0xFFEDE7E4),
  });

  final Dish dish;
  final bool isSaved;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOpen;
  final RecipeDishCardLayout layout;
  final Alignment favoriteAlignment;
  final bool isFavoriteUpdating;
  final Color cardBorderColor;

  @override
  Widget build(BuildContext context) {
    final bool isGrid = layout == RecipeDishCardLayout.grid;
    final double cardWidth = isGrid ? double.infinity : 178;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          side: BorderSide(color: cardBorderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.image_not_supported_outlined),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: favoriteAlignment,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isFavoriteUpdating ? null : onFavoriteTap,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: isFavoriteUpdating
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      size: 18,
                                      color: isSaved ? const Color(0xFFFF5D33) : Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: Text(
                    dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    DishMetaPill(icon: Icons.schedule, label: '${dish.cookTime} min'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DishMetaPill(
                        icon: Icons.restaurant_menu,
                        label: '${dish.ingredients.length} ingredients',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onOpen,
                  child: Text(
                    'View recipe >',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DishMetaPill extends StatelessWidget {
  const DishMetaPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
