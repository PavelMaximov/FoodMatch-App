import 'package:flutter/material.dart';

import '../../data/models/dish.dart';
import 'dish_grid.dart';

class DishCardGrid extends StatelessWidget {
  const DishCardGrid({
    super.key,
    required this.dishes,
    required this.savedDishIds,
    required this.onFavoriteTap,
    required this.onDishTap,
    this.crossAxisCount = DishGrid.columns,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.shrinkWrap = false,
    this.childAspectRatio = DishGrid.childAspectRatio,
    this.crossAxisSpacing = DishGrid.spacing,
    this.mainAxisSpacing = DishGrid.spacing,
    this.favoriteAlignment = Alignment.topRight,
    this.isFavoriteUpdating,
    this.cardBorderColor,
  });

  final List<Dish> dishes;
  final Set<String> savedDishIds;
  final Future<void> Function(Dish dish) onFavoriteTap;
  final void Function(Dish dish) onDishTap;
  final int crossAxisCount;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool shrinkWrap;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Alignment favoriteAlignment;
  final bool Function(String dishId)? isFavoriteUpdating;
  final Color? cardBorderColor;

  @override
  Widget build(BuildContext context) {
    return DishGrid(
      dishes: dishes,
      savedDishIds: savedDishIds,
      onFavoriteTap: onFavoriteTap,
      onDishTap: onDishTap,
      isFavoriteUpdating: isFavoriteUpdating,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
    );
  }
}
