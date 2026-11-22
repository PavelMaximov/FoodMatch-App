import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/shopping_list/domain/shopping_list_item.dart';
import 'package:food_match/features/dishes/domain/ingredient_display_parser.dart';
import 'package:food_match/data/models/content_units.dart';

void main() {
  test('Shopping labels switch after cache reload without changing merge keys', () {
    final now = DateTime(2026);
    final item = ShoppingListItem(id: 'one', name: 'tomato', nameDe: 'Tomate',
      normalizedName: 'tomato', checked: false, sortOrder: 0,
      createdAt: now, updatedAt: now);
    final cached = ShoppingListItem.fromJson(item.toJson()).copyWith(checked: true);
    expect(cached.displayName('de'), 'Tomate');
    expect(cached.displayName('en'), 'tomato');
    expect(cached.normalizedName, 'tomato');
    final legacy = item.toJson()..remove('nameDe');
    expect(ShoppingListItem.fromJson(legacy).displayName('de'), 'tomato');
  });
  test('German ingredient measurements remain separate from grocery names', () {
    final parsed = splitIngredientDisplay('1,5 EL Olivenöl');
    expect(parsed.measurement, '1,5 EL');
    expect(parsed.name, 'Olivenöl');
    expect(splitIngredientDisplay('2 Stück Tomaten').name, 'Tomaten');
    expect(contentUnit('tbsp', 'de'), 'EL');
    expect(contentUnit('tbsp', 'en'), 'tbsp');
    expect(contentUnit('unknown', 'de'), 'unknown');
  });
}
