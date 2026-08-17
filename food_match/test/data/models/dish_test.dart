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
  test('normalizes time fields and display fallbacks', () {
    expect(Dish.fromJson({'total_time_minutes': 90, 'cookTime': 25}).totalTimeDisplay, '1 hr 30 min');
    expect(Dish.fromJson({'cookTime': 25}).totalTimeDisplay, '25 min');
    expect(Dish.fromJson({'prep_time_minutes': 10, 'cook_time_minutes': 50}).totalTimeDisplay, '1 hr');
    expect(Dish.fromJson({'total_time_tier': {'display_tier': 'Under 30 min'}}).totalTimeDisplay, 'Under 30 min');
  });

  test('Dish.fromJson parses normalized rich ingredient sections', () {
    final Dish dish = Dish.fromJson(<String, dynamic>{
      'id': 'rich',
      'ingredients': <String>['spaghetti'],
      'ingredientSections': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'Main',
          'position': 0,
          'components': <Map<String, dynamic>>[
            <String, dynamic>{
              'position': 1,
              'name': 'spaghetti',
              'displayName': 'spaghetti',
              'measurements': <Map<String, dynamic>>[
                <String, dynamic>{'quantity': 200, 'unit': 'g'},
              ],
            },
          ],
        },
      ],
    });

    expect(dish.ingredients, <String>['spaghetti']);
    expect(dish.sections.single.name, 'Main');
    expect(dish.sections.single.components.single.resolvedName, 'spaghetti');
    expect(
      dish.sections.single.components.single.measurements.single.quantity,
      '200',
    );
    expect(
      dish.sections.single.components.single.measurements.single.unit,
      'g',
    );
  });

  test('Dish.fromJson parses raw database ingredient sections', () {
    final Dish dish = Dish.fromJson(<String, dynamic>{
      'id': 'raw',
      'sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'components': <Map<String, dynamic>>[
            <String, dynamic>{
              'raw_text': '2 eggs',
              'ingredient': <String, dynamic>{
                'name': 'eggs',
                'display_plural': 'eggs',
              },
              'measurements': <Map<String, dynamic>>[
                <String, dynamic>{
                  'quantity': 2.0,
                  'unit': <String, dynamic>{'display_singular': 'piece'},
                },
              ],
            },
          ],
        },
      ],
    });

    final DishComponent component = dish.sections.single.components.single;
    expect(component.resolvedName, 'eggs');
    expect(component.rawText, '2 eggs');
    expect(component.measurements.single.quantity, '2.0');
    expect(component.measurements.single.unit, 'piece');
  });
}
