import '../../../data/models/dish.dart';

String formatIngredientQuantity(String? quantity) {
  final String value = quantity?.trim() ?? '';
  if (value.isEmpty) return '';
  final num? parsed = num.tryParse(value);
  if (parsed == null) return value;
  return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
}

String formatIngredientLine(DishComponent component) {
  final String name = component.resolvedName;
  final DishIngredientMeasurement? measurement =
      component.measurements.isEmpty ? null : component.measurements.first;
  final String quantity = formatIngredientQuantity(measurement?.quantity);
  final String unit = measurement?.unit?.trim() ?? '';
  return <String>[quantity, unit, name]
      .where((String part) => part.isNotEmpty)
      .join(' ');
}
