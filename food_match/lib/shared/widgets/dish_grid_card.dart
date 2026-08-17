import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/assets/app_empty_state_assets.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/dish_image_placeholders.dart';
import '../../core/utils/image_utils.dart';
import '../../core/widgets/food_match_ripple.dart';
import '../../data/models/dish.dart';
import 'media/safe_dish_image.dart';

class DishGridCard extends StatelessWidget {
  const DishGridCard({
    super.key,
    required this.dish,
    required this.isFavorite,
    this.onTap,
    this.onFavoriteTap,
    this.isLoading = false,
    this.heroTag,
    this.width,
  });

  final Dish dish;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final bool isLoading;
  final String? heroTag;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final Widget image = SafeDishImage(
      imageUrl: ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.dishCard),
      fit: BoxFit.cover,
      emptyImageAsset: isCustomDishWithoutPhoto(dish)
          ? AppEmptyStateAssets.customDishPlaceholder
          : null,
    );

    return SizedBox(
      width: width,
      child: FoodMatchRipple(
        onTap: onTap,
        enabled: onTap != null,
        borderRadius: BorderRadius.circular(_DishGridCardTokens.cardRadius),
        rippleColor: colors.neutralRipple,
        child: Material(
          color: colors.dishCardBackground,
          borderRadius: BorderRadius.circular(_DishGridCardTokens.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              color: colors.dishCardBackground,
              border: Border.all(color: colors.dishCardBorder),
              borderRadius: BorderRadius.circular(_DishGridCardTokens.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _DishGridCardTokens.imageInset,
                    _DishGridCardTokens.imageInset,
                    _DishGridCardTokens.imageInset,
                    0,
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(_DishGridCardTokens.imageRadius),
                          child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
                        ),
                        Positioned(
                          top: _DishGridCardTokens.overlayInset,
                          right: _DishGridCardTokens.overlayInset,
                          child: _FavoriteButton(
                            isFavorite: isFavorite,
                            isLoading: isLoading,
                            onTap: onFavoriteTap,
                          ),
                        ),
                        if (dish.totalTimeDisplay.isNotEmpty)
                          Positioned(
                            left: _DishGridCardTokens.overlayInset,
                            bottom: _DishGridCardTokens.overlayInset,
                            child: _MetaPill(
                             iconWidget: SvgPicture.asset(
                                  'assets/icons/time.svg',
                                  width: 10,
                                  height: 10,
                                  colorFilter: ColorFilter.mode(
                                    colors.metadataIcon,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              label: dish.totalTimeDisplay,
                            ),
                          ),
                        if (_difficultyLabel(dish.effort) != null)
                          Positioned(
                            right: _DishGridCardTokens.overlayInset,
                            bottom: _DishGridCardTokens.overlayInset,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 66),
                              child: _MetaPill(
                                iconWidget: SvgPicture.asset(
                                  'assets/icons/level.svg',
                                  width: 10,
                                  height: 10,
                                  colorFilter: ColorFilter.mode(
                                    colors.metadataIcon,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                label: _difficultyLabel(dish.effort)!,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _DishGridCardTokens.titlePaddingX,
                      _DishGridCardTokens.titlePaddingY,
                      _DishGridCardTokens.titlePaddingX,
                      _DishGridCardTokens.titlePaddingY,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dish.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.2,
                        ),
                      ),
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

  static String? _difficultyLabel(String value) {
    final String normalized = value.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'unknown') {
      return null;
    }
    if (normalized == 'easy') return 'Easy';
    if (normalized == 'medium' || normalized == 'moderate') return 'Med';
    if (normalized == 'hard') return 'Hard';
    if (normalized == 'complex') return 'Hard';
    return value.trim().length <= 7 ? value.trim() : value.trim().substring(0, 7);
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.isFavorite, required this.isLoading, this.onTap});

  final bool isFavorite;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fmColors.metadataPillBackground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                    color: isFavorite ? context.fmColors.favoriteActive : context.fmColors.favoriteInactive,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.iconWidget});

  final String label;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.fmColors.metadataPillBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (iconWidget != null) iconWidget!,
          if (iconWidget != null) const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.fmColors.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DishGridCardTokens {
  const _DishGridCardTokens._();

  static const double cardRadius = 16;
  static const double imageRadius = 13;
  static const double imageInset = 12;
  static const double overlayInset = 8;
  static const double titlePaddingX = 12;
  static const double titlePaddingY = 5;
}
