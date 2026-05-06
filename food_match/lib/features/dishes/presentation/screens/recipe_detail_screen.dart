import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/recipe_step.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../favorites/logic/favorites_provider.dart';
import '../../logic/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.dishId, this.dish, super.key});

  final String dishId;
  final Dish? dish;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  _DetailTab _activeTab = _DetailTab.ingredients;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipeForDish(
            dishId: widget.dishId,
            dish: widget.dish,
          );
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final RecipeProvider recipeProvider = context.watch<RecipeProvider>();
    final FavoritesProvider favoritesProvider = context.watch<FavoritesProvider>();
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

    if (recipeProvider.error != null && dish == null) {
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
          SliverToBoxAdapter(
            child: _ImageHeader(
              dish: dish,
              dishId: dish.id,
              isFavorite: favoritesProvider.isFavorite(dish.id),
              isFavoriteUpdating: favoritesProvider.isUpdating(dish.id),
              onFavoriteTap: () => context.read<FavoritesProvider>().toggleFavorite(dish),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: AppDimensions.paddingL),
                  Text(
                    dish.name.isNotEmpty ? dish.name : 'Dish ${widget.dishId}',
                    style: GoogleFonts.nunito(
                      fontSize: 56 * 0.8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dish.description.isNotEmpty ? dish.description : AppStrings.cooking,
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildDishTags(dish),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${dish.servings.isEmpty ? '2' : dish.servings} ${AppStrings.servings}',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.access_time, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${dish.cookTime <= 0 ? 0 : dish.cookTime} ${AppStrings.minutes}',
                        style: AppTextStyles.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  _Tabs(
                    activeTab: _activeTab,
                    onChanged: (_DetailTab tab) => setState(() => _activeTab = tab),
                  ),
                  const SizedBox(height: AppDimensions.paddingM),
                  if (_activeTab == _DetailTab.ingredients)
                    _IngredientsContent(ingredients: dish.ingredients)
                  else
                    _InstructionsContent(steps: dish.steps),
                  const SizedBox(height: AppDimensions.paddingXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDishTags(Dish dish) {
    final List<String> tags = <String>[
      dish.cuisine,
      dish.type,
      ...dish.mood,
      ...dish.diet,
    ]
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .take(4)
        .toList();

    if (tags.isEmpty) {
      return <Widget>[const _TagChip(label: 'Dish')];
    }

    return tags.map((String tag) => _TagChip(label: tag)).toList();
  }
}

enum _DetailTab { ingredients, instructions }

class _ImageHeader extends StatelessWidget {
  const _ImageHeader({
    required this.dish,
    required this.dishId,
    required this.isFavorite,
    required this.isFavoriteUpdating,
    required this.onFavoriteTap,
  });

  final Dish dish;
  final String dishId;
  final bool isFavorite;
  final bool isFavoriteUpdating;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SizedBox(
          height: 390,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
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
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: <Color>[Colors.black.withValues(alpha: 0.42), Colors.transparent],
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
        Positioned(
          top: 52,
          right: AppDimensions.paddingM,
          child: _IconCircleButton(
            icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
            iconColor: isFavorite ? const Color(0xFF5D4136) : AppColors.textPrimary,
            onTap: isFavoriteUpdating ? null : onFavoriteTap,
            isLoading: isFavoriteUpdating,
          ),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.activeTab, required this.onChanged});

  final _DetailTab activeTab;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _TabButton(
          title: AppStrings.ingredients,
          isActive: activeTab == _DetailTab.ingredients,
          onTap: () => onChanged(_DetailTab.ingredients),
        ),
        const SizedBox(width: 8),
        _TabButton(
          title: 'Instructions',
          isActive: activeTab == _DetailTab.instructions,
          onTap: () => onChanged(_DetailTab.instructions),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFDCD0) : const Color(0xFFF0EDEB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _IngredientsContent extends StatelessWidget {
  const _IngredientsContent({required this.ingredients});

  final List<String> ingredients;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return Text('No ingredients available.', style: AppTextStyles.bodyMedium);
    }

    return Column(
      children: ingredients
          .map(
            (String ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ingredient,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.divider),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InstructionsContent extends StatelessWidget {
  const _InstructionsContent({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text('No instructions available.', style: AppTextStyles.bodyMedium);
    }

    return Column(
      children: steps
          .asMap()
          .entries
          .map(
            (MapEntry<int, RecipeStep> entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.textPrimary, width: 2),
                    ),
                    child: Text(
                      '${entry.value.step > 0 ? entry.value.step : entry.key + 1}',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Step ${entry.value.step > 0 ? entry.value.step : entry.key + 1}',
                          style: GoogleFonts.nunito(
                            fontSize: 31 * 0.62,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(entry.value.text, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF888888), width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: const Color(0xFF666666),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({
    required this.icon,
    this.onTap,
    this.iconColor = AppColors.textPrimary,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color iconColor;
  final bool isLoading;

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
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}
