import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/recipe_step.dart';

void main() {
  test('RecipeStep.fromJson parses fields', () {
    final model = RecipeStep.fromJson({'title': 'Step 1', 'text': 'Do this'});

    expect(model.title, 'Step 1');
    expect(model.text, 'Do this');
  });
}
