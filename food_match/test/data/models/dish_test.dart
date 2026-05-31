import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';

void main() {
  test('Dish.fromJson parses the current dish contract', () {
    final Map<String, dynamic> json = <String, dynamic>{
      'id': '123',
      'name': 'Borscht',
      'description': 'Classic beet soup',
      'imageUrl': 'https://example.com/borscht.jpg',
      'cuisine': 'Russian',
      'type': 'soup',
      'mood': <String>['comfort'],
      'diet': <String>['vegetarian'],
      'ingredients': <String>['beet', 'cabbage'],
      'cookTime': 45,
      'calories': '320 kcal',
      'effort': 'medium',
      'source': <String>['user'],
      'servings': '4',
      'season': <String>['winter'],
      'popular': true,
      'qualityScore': 4.5,
      'tags': <String>['soup', 'hot'],
      'steps': <Map<String, dynamic>>[
        <String, dynamic>{'step': 1, 'text': 'Slice vegetables'},
      ],
    };

    final Dish dish = Dish.fromJson(json);

    expect(dish.id, '123');
    expect(dish.name, 'Borscht');
    expect(dish.ingredients, <String>['beet', 'cabbage']);
    expect(dish.steps.single.step, 1);
    expect(dish.steps.single.text, 'Slice vegetables');
    expect(dish.tags, <String>['soup', 'hot']);
  });

  test('Dish.fromJson uses defaults for omitted optional fields', () {
    final Dish dish = Dish.fromJson(<String, dynamic>{'id': '456', 'name': 'Salad'});

    expect(dish.id, '456');
    expect(dish.name, 'Salad');
    expect(dish.description, isEmpty);
    expect(dish.mood, isEmpty);
    expect(dish.steps, isEmpty);
    expect(dish.popular, isFalse);
  });
}
