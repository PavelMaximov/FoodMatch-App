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
    this.footer,
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
  final Widget? footer;

  static const int columns = 2;
  static const double spacing = 15;
  static const double childAspectRatio = 1.08;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      cacheExtent: 900,
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate((_, int index) {
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
            }, childCount: dishes.length),
          ),
        ),
        if (footer != null) SliverToBoxAdapter(child: footer!),
      ],
    );
  }
}
