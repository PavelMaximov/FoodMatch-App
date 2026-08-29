class IngredientDisplayParts {
  const IngredientDisplayParts({
    required this.measurement,
    required this.name,
    required this.original,
    required this.hasQuantityPrefix,
  });

  final String measurement;
  final String name;
  final String original;
  final bool hasQuantityPrefix;
}

final RegExp _ingredientPrefix = RegExp(
  r'^(?:(about|approx\.)\s+)?'
  r'(\d+\s+\d+/\d+|\d+(?:\.\d+)?(?:[-–]\d+(?:\.\d+)?)?|\d+/\d+|[¼½¾])'
  r'(?:\s+(kg|g|ml|l|tsp|tbsp|cups?|oz|lb|cloves?|slices?|pieces?|pinch|handful))?'
  r'(?=\s|$)',
  caseSensitive: false,
);

/// Splits only a confident leading quantity (and optional known unit).
/// Unrecognised text is returned intact as the regular-name portion.
IngredientDisplayParts splitIngredientDisplay(String value) {
  final String clean = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final RegExpMatch? match = _ingredientPrefix.firstMatch(clean);
  if (match == null) {
    return IngredientDisplayParts(
      measurement: '',
      name: clean,
      original: clean,
      hasQuantityPrefix: false,
    );
  }

  final String measurement = match.group(0)!.trim();
  final String name = clean.substring(match.end).trimLeft();
  return IngredientDisplayParts(
    measurement: measurement,
    name: name,
    original: clean,
    hasQuantityPrefix: true,
  );
}
