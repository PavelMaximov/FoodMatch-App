import '../../data/models/dish.dart';

bool isCustomDishWithoutPhoto(Dish dish) {
  return dish.imageUrl.trim().isEmpty &&
      dish.source.any((String source) => source.trim().toLowerCase() == 'user');
}
