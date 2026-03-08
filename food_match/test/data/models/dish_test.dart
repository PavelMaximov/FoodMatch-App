import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';

void main() {
  test('Dish.fromJson парсит полный JSON с рецептом', () {
    final json = {
      '_id': '123',
      'title': 'Борщ',
      'description': 'Классический борщ',
      'imageUrl': 'https://example.com/borsh.jpg',
      'cuisine': 'Russian',
      'tags': ['суп', 'горячее'],
      'source': 'user',
      'externalId': null,
      'createdBy': 'user123',
      'recipe': {
        'ingredients': ['свёкла', 'капуста'],
        'steps': [
          {'title': 'Шаг 1', 'text': 'Нарезать овощи'}
        ]
      }
    };
    final dish = Dish.fromJson(json);
    expect(dish.id, '123');
    expect(dish.title, 'Борщ');
    expect(dish.recipe, isNotNull);
    expect(dish.recipe!.ingredients.length, 2);
  });

  test('Dish.fromJson парсит JSON без рецепта', () {
    final json = {
      '_id': '456',
      'title': 'Салат',
      'description': 'Простой салат',
      'imageUrl': 'https://example.com/salad.jpg',
      'cuisine': 'Italian',
      'tags': [],
      'source': 'mealdb',
      'externalId': '52772',
      'createdBy': 'user456',
    };
    final dish = Dish.fromJson(json);
    expect(dish.id, '456');
    expect(dish.recipe, isNull);
    expect(dish.externalId, '52772');
  });
}
