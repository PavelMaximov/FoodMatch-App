import '../../../data/models/dish.dart';
import '../../../data/models/measurement_system.dart';

DishIngredientMeasurement? selectIngredientMeasurement(
  List<DishIngredientMeasurement> measurements,
  MeasurementSystem system,
) {
  final candidates = measurements.where((value) =>
      (value.quantity?.trim().isNotEmpty ?? false) ||
      (value.unit?.trim().isNotEmpty ?? false)).toList();
  if (candidates.isEmpty) return null;
  for (final target in <String>[system.name, 'universal']) {
    for (final measurement in candidates) {
      final recordSystem = measurement.system?.trim().toLowerCase() ?? '';
      if (recordSystem == target || (target == 'universal' && recordSystem.isEmpty)) {
        return measurement;
      }
    }
  }
  return candidates.first;
}

String formatIngredientQuantity(String? quantity) {
  final String value = quantity?.trim() ?? '';
  if (value.isEmpty) return '';
  final num? parsed = num.tryParse(value);
  if (parsed == null) return value;
  return parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
}

String formatIngredientMeasurement(DishIngredientMeasurement? measurement) {
  final String quantity = formatIngredientQuantity(measurement?.quantity);
  final String unit = measurement?.unit?.trim() ?? '';
  return <String>[quantity, unit]
      .where((String part) => part.isNotEmpty)
      .join(' ');
}

String formatIngredientLine(DishComponent component,
    {MeasurementSystem system = MeasurementSystem.metric}) {
  final String name = component.resolvedName;
  final DishIngredientMeasurement? measurement =
      selectIngredientMeasurement(component.measurements, system);
  final String measurementText = formatIngredientMeasurement(measurement);
  return <String>[measurementText, name]
      .where((String part) => part.isNotEmpty)
      .join(' ');
}
