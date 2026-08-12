/// Canonical taxonomy values shared with the dish database and filters.
abstract final class DishTaxonomy {
  static const List<String> cuisines = <String>[
    'american',
    'asian',
    'balkan',
    'eastern_eu',
    'french',
    'german',
    'indian',
    'italian',
    'japanese',
    'mediterranean',
    'mexican',
    'middle_east',
    'spanish',
    'turkish',
  ];

  static const List<String> mealFormats = <String>[
    'everyday_staple',
    'home_classic',
    'celebration',
    'restaurant_style',
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
    'eastern_eu': 'Eastern EU',
    'french': 'French',
    'german': 'German',
    'indian': 'Indian',
    'italian': 'Italian',
    'japanese': 'Japanese',
    'mediterranean': 'Mediterranean',
    'mexican': 'Mexican',
    'middle_east': 'Middle East',
    'spanish': 'Spanish',
    'turkish': 'Turkish',
    'comfort': 'Comfort',
    'healthy': 'Healthy',
    'exotic': 'Exotic',
    'indulgent': 'Indulgent',
    'quick': 'Quick',
    'light': 'Light',
    'everyday_staple': 'Daily meal',
    'home_classic': 'Homestyle dish',
    'celebration': 'Celebration menu',
    'restaurant_style': 'Restaurant style',
  };

  static String labelFor(String value) => _labels[value] ?? value;
}
