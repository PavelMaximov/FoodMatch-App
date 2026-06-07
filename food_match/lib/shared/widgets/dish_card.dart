import 'package:flutter/material.dart';

import 'safe_network_image.dart';
import 'package:food_match/core/theme/app_colors.dart';
import 'package:food_match/core/theme/app_dimensions.dart';
import 'package:food_match/core/utils/image_utils.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:google_fonts/google_fonts.dart';

enum DishCardVariant { grid, horizontalRail }

class DishCard extends StatelessWidget {
  const DishCard({
    super.key,
    required this.dish,
    required this.isSaved,
    required this.onFavoriteTap,
    required this.onOpen,
    this.variant = DishCardVariant.grid,
    this.favoriteAlignment = Alignment.topRight,
    this.isFavoriteUpdating = false,
  });

  final Dish dish;
  final bool isSaved;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOpen;
  final DishCardVariant variant;
  final Alignment favoriteAlignment;
  final bool isFavoriteUpdating;

  @override
  Widget build(BuildContext context) {
    final double? cardWidth =
        variant == DishCardVariant.horizontalRail ? _DishCardTokens.railCardWidth : null;

    return SizedBox(
      width: cardWidth,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_DishCardTokens.cardRadius),
          side: const BorderSide(color: _DishCardTokens.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _DishCardTokens.contentHorizontal,
              _DishCardTokens.contentTop,
              _DishCardTokens.contentHorizontal,
              _DishCardTokens.contentBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_DishCardTokens.imageRadius),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: SafeNetworkImage(
                          imageUrl: ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.dishCard),
                          fit: BoxFit.cover,

                        ),
                      ),
                    ),
                    Align(
                      alignment: favoriteAlignment,
                      child: Padding(
                        padding: const EdgeInsets.all(_DishCardTokens.favoriteInset),
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: isFavoriteUpdating ? null : onFavoriteTap,
                            child: Padding(
                              padding: const EdgeInsets.all(_DishCardTokens.favoritePadding),
                              child: isFavoriteUpdating
                                  ? const SizedBox(
                                      width: _DishCardTokens.favoriteSpinnerSize,
                                      height: _DishCardTokens.favoriteSpinnerSize,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      size: _DishCardTokens.favoriteIconSize,
                                      color: isSaved ? const Color(0xFFFF5D33) : Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _DishCardTokens.gapAfterImage),
                Text(
                  dish.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: _DishCardTokens.titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: _DishCardTokens.gapAfterTitle),
                Row(
                  children: <Widget>[
                    _DishMetaPill(icon: Icons.schedule, labelBuilder: _DishCardLabelBuilder.cookTime, dish: dish),
                    const SizedBox(width: _DishCardTokens.pillGap),
                    Expanded(
                      child: _DishMetaPill(
                        icon: Icons.restaurant_menu,
                        labelBuilder: _DishCardLabelBuilder.ingredients,
                        dish: dish,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: _DishCardTokens.gapBeforeAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DishCardGrid extends StatelessWidget {
  const DishCardGrid({
    super.key,
    required this.dishes,
    required this.crossAxisCount,
    required this.savedDishIds,
    required this.onFavoriteTap,
    required this.onDishTap,
    this.isFavoriteUpdating,
    this.favoriteAlignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(16),
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 0.72,
    this.physics = const AlwaysScrollableScrollPhysics(),
  });

  final List<Dish> dishes;
  final int crossAxisCount;
  final Set<String> savedDishIds;
  final Future<void> Function(Dish) onFavoriteTap;
  final void Function(Dish) onDishTap;
  final bool Function(String dishId)? isFavoriteUpdating;
  final Alignment favoriteAlignment;
  final EdgeInsetsGeometry padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final ScrollPhysics physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: dishes.length,
      itemBuilder: (_, int index) {
        final Dish dish = dishes[index];
        return DishCard(
          dish: dish,
          isSaved: savedDishIds.contains(dish.id),
          isFavoriteUpdating: isFavoriteUpdating?.call(dish.id) ?? false,
          onFavoriteTap: () => onFavoriteTap(dish),
          onOpen: () => onDishTap(dish),
          favoriteAlignment: favoriteAlignment,
        );
      },
    );
  }
}

class _DishMetaPill extends StatelessWidget {
  const _DishMetaPill({required this.icon, required this.labelBuilder, this.dish});

  final IconData icon;
  final String Function(Dish? dish) labelBuilder;
  final Dish? dish;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _DishCardTokens.pillPaddingX, vertical: _DishCardTokens.pillPaddingY),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: _DishCardTokens.pillIconSize, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              labelBuilder(dish),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: _DishCardTokens.pillFontSize,
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

class _DishCardLabelBuilder {
  static String cookTime(Dish? dish) => '${dish?.cookTime ?? 0} min';
  static String ingredients(Dish? dish) => '${dish?.ingredients.length ?? 0} ingredients';
}

class _DishCardTokens {
  static const double railCardWidth = 178;
  static const double cardRadius = AppDimensions.radiusL;
  static const Color borderColor = Color(0xFFEDE7E4);
  static const double imageRadius = 14;
  static const double contentHorizontal = 10;
  static const double contentTop = 10;
  static const double contentBottom = 12;
  static const double titleFontSize = 14;
  static const double gapAfterImage = 10;
  static const double gapAfterTitle = 9;
  static const double gapBeforeAction = 10;
  static const double pillGap = 8;
  static const double favoriteInset = 8;
  static const double favoritePadding = 6;
  static const double favoriteIconSize = 18;
  static const double favoriteSpinnerSize = 16;
  static const double pillPaddingX = 8;
  static const double pillPaddingY = 5;
  static const double pillIconSize = 13;
  static const double pillFontSize = 11;
}
