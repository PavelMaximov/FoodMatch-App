import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shopping_list_item.dart';

class ShoppingListStorage {
  ShoppingListStorage({SharedPreferences? preferences}) : _preferences = preferences;

  static const String storageKey = 'foodmatch_shopping_list_v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<ShoppingListItem>> load() async {
    try {
      final String? value = (await _prefs).getString(storageKey);
      if (value == null) return <ShoppingListItem>[];
      final List<dynamic> decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .map((dynamic item) => ShoppingListItem.fromJson(
                Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
              ))
          .toList();
    } catch (_) {
      return <ShoppingListItem>[];
    }
  }

  Future<void> save(List<ShoppingListItem> items) async {
    await (await _prefs).setString(
      storageKey,
      jsonEncode(items.map((ShoppingListItem item) => item.toJson()).toList()),
    );
  }
}
