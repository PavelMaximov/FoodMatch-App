import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/notification_theme.dart';
import '../../core/utils/food_match_notifications.dart';
import '../../data/models/dish.dart';
import '../../features/favorites/logic/favorites_provider.dart';

Future<void> toggleDishFavorite(BuildContext context, Dish dish) async {
  final favorites = context.read<FavoritesProvider>();
  if (favorites.isUpdating(dish.id)) return;
  await favorites.toggleFavorite(dish);
  if (!context.mounted) return;
  final error = favorites.error;
  if (error != null) {
    FoodMatchNotifications.show(context,
      type: FoodMatchNotificationType.error, title: error);
  }
}
