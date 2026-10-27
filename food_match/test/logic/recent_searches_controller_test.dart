import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_match/shared/logic/recent_searches_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('edits beat a delayed initial read and persist in order', () async {
    SharedPreferences.setMockInitialValues({'history': ['old']});
    final history = RecentSearchesController('history');
    final load = history.load();
    final save = history.remember(' New ');
    await load;
    await save;
    expect(history.items, ['New']);
    final first = history.remember('another');
    final clear = history.clear();
    await first;
    await clear;
    expect((await SharedPreferences.getInstance()).getStringList('history'), isEmpty);
    history.dispose();
  });

  test('history is case insensitive, bounded, and separated by storage key', () async {
    final recipes = RecentSearchesController('recipes');
    for (var i = 0; i < 12; i++) { await recipes.remember('Dish $i'); }
    await recipes.remember('dish 11');
    expect(recipes.items, hasLength(10));
    expect(recipes.items.first, 'dish 11');
    final favorites = RecentSearchesController('favorites');
    await favorites.load();
    expect(favorites.items, isEmpty);
    recipes.dispose();
    favorites.dispose();
  });
}
