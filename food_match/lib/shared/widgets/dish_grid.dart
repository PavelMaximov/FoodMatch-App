import 'package:flutter/material.dart';

import '../../data/models/dish.dart';
import 'dish_grid_card.dart';

class DishGrid extends StatelessWidget {
  const DishGrid({
    super.key,
    required this.dishes,
    required this.savedDishIds,
    required this.onFavoriteTap,
    required this.onDishTap,
    this.isFavoriteUpdating,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.shrinkWrap = false,
    this.controller,
  });

  final List<Dish> dishes;
  final Set<String> savedDishIds;
  final Future<void> Function(Dish dish) onFavoriteTap;
  final void Function(Dish dish) onDishTap;
  final bool Function(String dishId)? isFavoriteUpdating;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool shrinkWrap;
  final ScrollController? controller;

  static const int columns = 2;
  static const double spacing = 15;
  static const double childAspectRatio = 0.86;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: dishes.length,
      itemBuilder: (_, int index) {
        final Dish dish = dishes[index];
        return RepaintBoundary(
          key: ValueKey<String>(dish.id),
          child: DishGridCard(
            dish: dish,
            isFavorite: savedDishIds.contains(dish.id),
            isLoading: isFavoriteUpdating?.call(dish.id) ?? false,
            onFavoriteTap: () => onFavoriteTap(dish),
            onTap: () => onDishTap(dish),
          ),
        );
      },
    );
  }
}
