import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/recipe.dart';

void main() {
  test('Recipe.fromJson parses ingredients and steps', () {
    final model = Recipe.fromJson({
      'ingredients': ['a', 'b'],
      'steps': [
        {'title': 'S1', 'text': 'T1'}
      ],
    });

    expect(model.ingredients.length, 2);
    expect(model.steps.first.title, 'S1');
  });
}
