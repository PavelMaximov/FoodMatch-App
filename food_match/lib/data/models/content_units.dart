/// Display labels only: persisted measurement codes remain canonical.
String contentUnit(String value, String languageCode) {
  if (languageCode != 'de') return value;
  return _germanUnits[value.trim().toLowerCase()] ?? value;
}

const _germanUnits = <String, String>{
  'tsp': 'TL',
  'teaspoon': 'TL',
  'teaspoons': 'TL',
  'tbsp': 'EL',
  'tablespoon': 'EL',
  'tablespoons': 'EL',
  'cup': 'Tasse',
  'cups': 'Tassen',
  'piece': 'Stück',
  'pieces': 'Stück',
  'pcs': 'Stück',
  'clove': 'Zehe',
  'cloves': 'Zehen',
  'slice': 'Scheibe',
  'slices': 'Scheiben',
  'pinch': 'Prise',
  'handful': 'Handvoll',
  'bunch': 'Bund',
  'sprig': 'Zweig',
  'sprigs': 'Zweige',
  'can': 'Dose',
  'cans': 'Dosen',
  'gram': 'g',
  'grams': 'g',
  'kilogram': 'kg',
  'kilograms': 'kg',
  'milliliter': 'ml',
  'milliliters': 'ml',
  'liter': 'l',
  'liters': 'l',
};
