import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/features/dishes/domain/ingredient_formatter.dart';
import 'package:food_match/data/models/measurement_system.dart';

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

  test('trims compound units and supports quantity-only measurements', () {
    const DishIngredientMeasurement compound = DishIngredientMeasurement(
      quantity: '1.0',
      unit: '  tbsp chopped  ',
    );
    const DishIngredientMeasurement quantityOnly =
        DishIngredientMeasurement(quantity: '200');

    expect(formatIngredientMeasurement(compound), '1 tbsp chopped');
    expect(formatIngredientMeasurement(quantityOnly), '200');
  });

  group('measurement selection', () {
    const metric = DishIngredientMeasurement(quantity: '250.0', unit: 'g', system: 'metric');
    const imperial = DishIngredientMeasurement(quantity: '8.8', unit: 'oz', system: 'imperial');
    const universal = DishIngredientMeasurement(quantity: '1', unit: 'medium', system: 'universal');

    test('prefers the resolved system over other records', () {
      expect(selectIngredientMeasurement(const [imperial, universal, metric], MeasurementSystem.metric), metric);
      expect(selectIngredientMeasurement(const [metric, universal, imperial], MeasurementSystem.imperial), imperial);
    });

    test('uses universal before the opposite system', () {
      expect(selectIngredientMeasurement(const [imperial, universal], MeasurementSystem.metric), universal);
      expect(selectIngredientMeasurement(const [metric, universal], MeasurementSystem.imperial), universal);
    });

    test('falls back to the opposite system and handles missing system', () {
      expect(selectIngredientMeasurement(const [imperial], MeasurementSystem.metric), imperial);
      expect(selectIngredientMeasurement(const [metric], MeasurementSystem.imperial), metric);
      const legacy = DishIngredientMeasurement(quantity: '2.0', unit: 'piece');
      expect(selectIngredientMeasurement(const [legacy], MeasurementSystem.metric), legacy);
      expect(formatIngredientMeasurement(legacy), '2 piece');
      expect(selectIngredientMeasurement(const [], MeasurementSystem.metric), isNull);
    });
  });
}
