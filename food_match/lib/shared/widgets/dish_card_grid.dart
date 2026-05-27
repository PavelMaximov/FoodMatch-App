import 'package:flutter/material.dart';

import '../../data/models/dish.dart';
import 'recipe_dish_card.dart';
import 'recipe_dish_layout.dart';

class DishCardGrid extends StatelessWidget {
  const DishCardGrid({
    super.key,
    required this.dishes,
    required this.savedDishIds,
    required this.onFavoriteTap,
    this.crossAxisCount = RecipeDishLayoutStyle.defaultGridColumns,
    this.padding = RecipeDishLayoutStyle.gridPadding,
    this.physics,
    this.shrinkWrap = false,
    this.childAspectRatio = RecipeDishLayoutStyle.gridChildAspectRatio,
    this.crossAxisSpacing = RecipeDishLayoutStyle.gridCrossAxisSpacing,
    this.mainAxisSpacing = RecipeDishLayoutStyle.gridMainAxisSpacing,
    this.favoriteAlignment = Alignment.topRight,
    this.isFavoriteUpdating,
  });

  final List<Dish> dishes;
  final Set<String> savedDishIds;
  final Future<void> Function(Dish dish) onFavoriteTap;
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Alignment favoriteAlignment;
  final bool Function(String dishId)? isFavoriteUpdating;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: RecipeDishLayoutStyle.gridDelegate(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: dishes.length,
      itemBuilder: (_, int index) {
        final Dish dish = dishes[index];

        return RecipeDishCard(
          dish: dish,
          isSaved: savedDishIds.contains(dish.id),
          onFavoriteTap: () => onFavoriteTap(dish),
          isFavoriteUpdating: isFavoriteUpdating?.call(dish.id) ?? false,
          favoriteAlignment: favoriteAlignment,
          layout: RecipeDishCardLayout.grid,
        );
      },
    );
  }
}
