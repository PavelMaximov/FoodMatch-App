import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_match/features/shopping_list/data/shopping_list_storage.dart';
import 'package:food_match/features/shopping_list/logic/shopping_list_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('adds trimmed unique ingredients and persists them', () async {
    final ShoppingListProvider provider = ShoppingListProvider();

    final int added = await provider.addIngredients(
      ingredients: <String>[' Tomato ', 'tomato', '', 'Basil'],
      sourceDishId: 'dish-1',
      sourceDishName: 'Pasta',
    );

    expect(added, 2);
    expect(provider.items.map((item) => item.name), <String>['Tomato', 'Basil']);
    final ShoppingListProvider restored = ShoppingListProvider();
    await restored.load();
    expect(restored.items, hasLength(2));
    expect(restored.items.first.sourceDishId, 'dish-1');
  });

  test('manual duplicates fill missing details without adding a row', () async {
    final ShoppingListProvider provider = ShoppingListProvider();
    await provider.addManualItem(name: 'Milk');
    await provider.addManualItem(name: ' milk ', quantity: '2', measure: 'l');

    expect(provider.items, hasLength(1));
    expect(provider.items.single.quantity, '2');
    expect(provider.items.single.measure, 'l');
  });

  test('toggle, reset, and reorder preserve item data', () async {
    final ShoppingListProvider provider = ShoppingListProvider();
    await provider.addManualItem(name: 'Apples');
    await provider.addManualItem(name: 'Bread');
    final String applesId = provider.items.first.id;

    await provider.toggleChecked(applesId);
    expect(provider.checkedCount, 1);
    await provider.reorder(0, 2);
    expect(provider.items.last.id, applesId);
    expect(provider.items.last.checked, isTrue);
    expect(provider.items.map((item) => item.sortOrder), <int>[0, 1]);
    await provider.resetChecked();
    expect(provider.checkedCount, 0);
  });

  test('corrupted local JSON loads as an empty list', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ShoppingListStorage.storageKey: '{not-json',
    });
    final ShoppingListProvider provider = ShoppingListProvider();

    await provider.load();

    expect(provider.items, isEmpty);
  });
}
