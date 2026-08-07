/// Canonical taxonomy values shared with the dish database and filters.
abstract final class DishTaxonomy {
  static const List<String> cuisines = <String>[
    'american',
    'asian',
    'balkan',
    'eastern UE',
    'french',
    'german',
    'indian',
    'italien',
    'japanese',
    'mediterranean',
    'mexican',
    'middle east',
    'spanish',
    'turkish',
  ];

  static const List<String> moods = <String>[
    'comfort',
    'healthy',
    'exotic',
    'indulgent',
    'quick',
    'light',
  ];

  static const Map<String, String> _labels = <String, String>{
    'american': 'American',
    'asian': 'Asian',
    'balkan': 'Balkan',
    'eastern UE': 'Eastern UE',
    'french': 'French',
    'german': 'German',
    'indian': 'Indian',
    'italien': 'Italien',
    'japanese': 'Japanese',
    'mediterranean': 'Mediterranean',
    'mexican': 'Mexican',
    'middle east': 'Middle East',
    'spanish': 'Spanish',
    'turkish': 'Turkish',
    'comfort': 'Comfort',
    'healthy': 'Healthy',
    'exotic': 'Exotic',
    'indulgent': 'Indulgent',
    'quick': 'Quick',
    'light': 'Light',
  };

  static String labelFor(String value) => _labels[value] ?? value;
}
