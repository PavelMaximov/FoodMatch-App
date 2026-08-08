import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/features/dishes/domain/ingredient_formatter.dart';

void main() {
  test('formats quantity, unit, and ingredient without trailing decimals', () {
    const DishComponent component = DishComponent(
      ingredient: DishIngredient(name: 'eggs'),
      measurements: <DishIngredientMeasurement>[
        DishIngredientMeasurement(quantity: '2.0', unit: 'piece'),
      ],
    );

    expect(formatIngredientLine(component), '2 piece eggs');
    expect(
      formatIngredientMeasurement(component.measurements.first),
      '2 piece',
    );
  });

  test('formats decimal quantity and falls back to ingredient name', () {
    const DishComponent measured = DishComponent(
      ingredient: DishIngredient(name: 'black pepper'),
      measurements: <DishIngredientMeasurement>[
        DishIngredientMeasurement(quantity: '0.5', unit: 'tsp'),
      ],
    );
    const DishComponent unmeasured = DishComponent(
      ingredient: DishIngredient(name: 'onion'),
    );

    expect(formatIngredientLine(measured), '0.5 tsp black pepper');
    expect(formatIngredientLine(unmeasured), 'onion');
  });
}
