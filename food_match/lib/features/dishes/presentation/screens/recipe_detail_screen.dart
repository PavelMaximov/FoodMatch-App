import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../logic/recipe_provider.dart';
import '../../../../core/constants/app_strings.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.dishId, this.dish, super.key});

  final String dishId;
  final Dish? dish;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipeForDish(
            dishId: widget.dishId,
            dish: widget.dish,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final RecipeProvider recipeProvider = context.watch<RecipeProvider>();
    final Dish? dish = recipeProvider.currentDish;

    if (recipeProvider.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: EdgeInsets.all(AppDimensions.paddingM),
          child: ShimmerCard(),
        ),
      );
    }

    if (recipeProvider.error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: ErrorState(
            message: recipeProvider.error!,
            onRetry: () => context.read<RecipeProvider>().loadRecipeForDish(
              dishId: widget.dishId,
              dish: widget.dish,
            ),
          ),
        ),
      );
    }

    if (dish == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Center(
                  child: Text(
                    AppStrings.recipeNotAvailable,
                    style: AppTextStyles.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _ImageHeader(dish: dish, dishId: dish.id)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppDimensions.paddingM),
                  Text(
                    dish.name.isNotEmpty ? dish.name : 'Dish ${widget.dishId}',
                    style: GoogleFonts.nunito(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.description.isNotEmpty ? dish.description : AppStrings.cooking,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  Text(
                    AppStrings.ingredients,
                    style: GoogleFonts.pacifico(
                      fontSize: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.people, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${dish.servings.isEmpty ? '2' : dish.servings} ${AppStrings.servings}',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${dish.cookTime} ${AppStrings.minutes}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...dish.ingredients.map(
                    (String ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(ingredient, style: AppTextStyles.bodyLarge),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: AppColors.divider),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppStrings.cooking,
                    style: GoogleFonts.pacifico(
                      fontSize: 24,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  ...dish.steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              '${entry.value.step > 0 ? entry.value.step : entry.key + 1}',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(entry.value.text, style: AppTextStyles.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({required this.dish, required this.dishId});

  final Dish dish;
  final String dishId;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SizedBox(
          height: 300,
          width: double.infinity,
          child: Hero(
            tag: 'dish-image-$dishId',
            child: CachedNetworkImage(
              imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: Colors.black12,
                child: const Icon(Icons.restaurant_menu, size: 72),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: <Color>[Colors.black.withValues(alpha: 0.45), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 52,
          left: AppDimensions.paddingM,
          child: _IconCircleButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
