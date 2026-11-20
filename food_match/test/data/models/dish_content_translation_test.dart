import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';

void main() {
  test('German display preserves canonical identities and cache round trip', () {
    final dish = Dish.fromJson({
      'id': 'stable', 'name': 'Rice', 'cuisine': 'german',
      'ingredients': ['100 g rice'],
      'steps': [{'step': 1, 'text': 'Cook for 10 minutes.'}],
      'contentTranslations': {'de': {
        'Rice': 'Reis', '100 g rice': '100 g Reis',
        'Cook for 10 minutes.': '10 Minuten kochen.',
      }},
    });
    final cached = Dish.fromJson(dish.toJson());
    final german = cached.displayForLanguage('de');
    expect(german.name, 'Reis');
    expect(german.ingredients, ['100 g Reis']);
    expect(german.steps.single.text, '10 Minuten kochen.');
    expect(german.id, cached.id);
    expect(german.cuisine, 'german');
    expect(cached.name, 'Rice');
    expect(cached.ingredients, ['100 g rice']);
    expect(identical(cached.displayForLanguage('en'), cached), isTrue);
    expect(identical(cached.displayForLanguage('de'), german), isTrue);
    expect(identical(cached.displayForLanguage('fr'), cached), isTrue);
  });
  test('Missing, malformed and custom translations keep original content', () {
    for (final raw in [null, [], {'de': []}, {'de': {'Rice': 42}}]) {
      final dish = Dish.fromJson({'name': 'Rice', 'contentTranslations': raw});
      expect(dish.displayForLanguage('de').name, 'Rice');
    }
    final custom = Dish.fromJson({'name': 'My rice', 'isCustom': true,
      'contentTranslations': {'de': {'My rice': 'Mein Reis'}}});
    expect(identical(custom.displayForLanguage('de'), custom), isTrue);
  });
}
