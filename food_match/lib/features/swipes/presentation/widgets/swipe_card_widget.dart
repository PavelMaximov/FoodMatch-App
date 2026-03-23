import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';

class SwipeCardWidget extends StatelessWidget {
  const SwipeCardWidget({required this.dish, super.key});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final List<String> chips = <String>[dish.cuisine, ...dish.tags];

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 65,
              child: Hero(
                tag: 'dish-image-${dish.id}',
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: AppColors.chipBg,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 35,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dish.title,
                      style: AppTextStyles.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dish.description,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Wrap(
                      spacing: AppDimensions.paddingS,
                      runSpacing: AppDimensions.paddingS,
                      children: chips
                          .map(
                            (String tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.chipBg,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                              ),
                              child: Text(
                                tag,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.chipText),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
