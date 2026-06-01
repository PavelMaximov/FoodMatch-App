import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/recipe.dart';

void main() {
  test('Recipe.fromJson parses ingredients and current step fields', () {
    final Recipe model = Recipe.fromJson(<String, dynamic>{
      'ingredients': <String>['a', 'b'],
      'steps': <Map<String, dynamic>>[
        <String, dynamic>{'step': 1, 'text': 'T1'},
      ],
    });

    expect(model.ingredients, <String>['a', 'b']);
    expect(model.steps.single.step, 1);
    expect(model.steps.single.text, 'T1');
  });
}
