import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/measurement_system.dart';
import 'package:food_match/features/dishes/domain/ingredient_display_parser.dart';
import 'package:food_match/features/dishes/domain/ingredient_formatter.dart';

void main() {
  group('ingredient display splitting', () {
    for (final (String input, String measurement, String name) in <(String, String, String)>[
      ('500 g chicken breast', '500 g', 'chicken breast'),
      ('1 cup rice', '1 cup', 'rice'),
      ('2 tbsp olive oil', '2 tbsp', 'olive oil'),
      ('4 piece eggs', '4 piece', 'eggs'),
      ('250 g chicken breast', '250 g', 'chicken breast'),
      ('1/2 tsp salt', '1/2 tsp', 'salt'),
      ('½ tsp salt', '½ tsp', 'salt'),
      ('1 1/2 cups flour', '1 1/2 cups', 'flour'),
      ('1–2 cloves garlic', '1–2 cloves', 'garlic'),
      ('about 2 slices bread', 'about 2 slices', 'bread'),
      ('approx. 0.5 kg potatoes', 'approx. 0.5 kg', 'potatoes'),
    ]) {
      test('keeps measurement and name for $input', () {
        final IngredientDisplayParts parts = splitIngredientDisplay(input);
        expect(parts.measurement, measurement);
        expect(parts.name, name);
        expect('${parts.measurement} ${parts.name}'.trim(), input);
      });
    }

    for (final String input in <String>['Salt, to taste', 'Parsley']) {
      test('keeps unmeasured ingredient intact: $input', () {
        final IngredientDisplayParts parts = splitIngredientDisplay(input);
        expect(parts.measurement, isEmpty);
        expect(parts.name, input);
      });
    }

    test('keeps a quantity-only value visible', () {
      final IngredientDisplayParts parts = splitIngredientDisplay('500 g');
      expect(parts.hasQuantityPrefix, isTrue);
      expect(parts.name, isEmpty);
      expect(parts.original, '500 g');
    });
  });

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
