import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/recipe_step.dart';

void main() {
  test('RecipeStep.fromJson parses current fields', () {
    final RecipeStep model = RecipeStep.fromJson(<String, dynamic>{
      'step': 1,
      'text': 'Do this',
    });

    expect(model.step, 1);
    expect(model.text, 'Do this');
  });
}
