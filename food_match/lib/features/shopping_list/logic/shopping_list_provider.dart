import 'package:flutter/foundation.dart';

import '../data/shopping_list_storage.dart';
import '../domain/shopping_list_item.dart';
import '../../dishes/domain/ingredient_display_parser.dart';

class ShoppingListIngredientInput {
  const ShoppingListIngredientInput({
    required this.name,
    this.quantity,
    this.measure,
  });

  factory ShoppingListIngredientInput.fromName(String name) =>
      ShoppingListIngredientInput(name: name);

  factory ShoppingListIngredientInput.fromDisplayText(String displayText) {
    final IngredientDisplayParts parts = splitIngredientDisplay(displayText);
    if (!parts.hasQuantityPrefix || parts.name.isEmpty) {
      return ShoppingListIngredientInput(name: parts.original);
    }
    final List<String> measurementParts = parts.measurement.split(' ');
    final bool hasUnit = measurementParts.length > 1 &&
        RegExp(r'^[A-Za-z]+\.?$').hasMatch(measurementParts.last);
    return ShoppingListIngredientInput(
      name: parts.name,
      quantity: hasUnit
          ? measurementParts.take(measurementParts.length - 1).join(' ')
          : parts.measurement,
      measure: hasUnit ? measurementParts.last : null,
    );
  }

  final String name;
  final String? quantity;
  final String? measure;
}

class ShoppingListProvider extends ChangeNotifier {
  ShoppingListProvider({ShoppingListStorage? storage})
      : _storage = storage ?? ShoppingListStorage();

  final ShoppingListStorage _storage;
  final List<ShoppingListItem> _items = <ShoppingListItem>[];
  int _idSequence = 0;
  bool _isLoaded = false;
  Future<void>? _loadFuture;

  List<ShoppingListItem> get items => List<ShoppingListItem>.unmodifiable(_items);
  int get checkedCount => _items.where((ShoppingListItem item) => item.checked).length;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;
    if (_loadFuture != null) {
      await _loadFuture;
      return;
    }
    _loadFuture = _loadFromStorage();
    await _loadFuture;
  }

  Future<void> _loadFromStorage() async {
    _items
      ..clear()
      ..addAll(await _storage.load())
      ..sort((ShoppingListItem a, ShoppingListItem b) => a.sortOrder.compareTo(b.sortOrder));
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> addManualItem({
    required String name,
    String? quantity,
    String? measure,
  }) async {
    await load();
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final String normalized = _normalize(cleanName);
    final String? cleanQuantity = _optional(quantity);
    final String? cleanMeasure = _optional(measure);
    final int existingIndex = _items.indexWhere(
      (ShoppingListItem item) => item.normalizedName == normalized,
    );
    if (existingIndex >= 0) {
      final ShoppingListItem existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity ?? cleanQuantity,
        measure: existing.measure ?? cleanMeasure,
        updatedAt: DateTime.now(),
      );
      await _persist();
      return;
    }
    final DateTime now = DateTime.now();
    _items.add(ShoppingListItem(
      id: '${now.microsecondsSinceEpoch}-${_idSequence++}',
      name: cleanName,
      normalizedName: normalized,
      quantity: cleanQuantity,
      measure: cleanMeasure,
      checked: false,
      sortOrder: _items.length,
      createdAt: now,
      updatedAt: now,
    ));
    await _persist();
  }

  Future<int> addIngredients({
    required List<ShoppingListIngredientInput> ingredients,
    String? sourceDishId,
    String? sourceDishName,
  }) async {
    await load();
    int added = 0;
    bool updated = false;
    for (final ShoppingListIngredientInput ingredient in ingredients) {
      final String name = ingredient.name.trim();
      final String normalized = _normalize(name);
      if (normalized.isEmpty) continue;
      final int existingIndex = _items.indexWhere(
        (ShoppingListItem item) => item.normalizedName == normalized,
      );
      if (existingIndex >= 0) {
        final ShoppingListItem existing = _items[existingIndex];
        final String? quantity = existing.quantity ?? _optional(ingredient.quantity);
        final String? measure = existing.measure ?? _optional(ingredient.measure);
        if (quantity != existing.quantity || measure != existing.measure) {
          _items[existingIndex] = existing.copyWith(
            quantity: quantity,
            measure: measure,
            updatedAt: DateTime.now(),
          );
          updated = true;
        }
        continue;
      }
      final DateTime now = DateTime.now();
      _items.add(ShoppingListItem(
        id: '${now.microsecondsSinceEpoch}-${_idSequence++}',
        name: name,
        normalizedName: normalized,
        quantity: _optional(ingredient.quantity),
        measure: _optional(ingredient.measure),
        sourceDishId: _optional(sourceDishId),
        sourceDishName: _optional(sourceDishName),
        checked: false,
        sortOrder: _items.length,
        createdAt: now,
        updatedAt: now,
      ));
      added++;
    }
    if (added > 0 || updated) await _persist();
    return added;
  }

  Future<int> addIngredientNames({
    required List<String> ingredients,
    String? sourceDishId,
    String? sourceDishName,
  }) =>
      addIngredients(
        ingredients: ingredients
            .map(ShoppingListIngredientInput.fromName)
            .toList(),
        sourceDishId: sourceDishId,
        sourceDishName: sourceDishName,
      );

  Future<void> toggleChecked(String id) async => _update(
        id,
        (ShoppingListItem item) => item.copyWith(
          checked: !item.checked,
          updatedAt: DateTime.now(),
        ),
      );

  Future<void> removeItem(String id) async {
    await load();
    _items.removeWhere((ShoppingListItem item) => item.id == id);
    await _renumberAndPersist();
  }

  Future<void> clearCompleted() async {
    await load();
    _items.removeWhere((ShoppingListItem item) => item.checked);
    await _renumberAndPersist();
  }

  Future<void> clearAll() async {
    await load();
    _items.clear();
    await _persist();
  }

  Future<void> resetChecked() async {
    await load();
    final DateTime now = DateTime.now();
    for (int index = 0; index < _items.length; index++) {
      if (_items[index].checked) {
        _items[index] = _items[index].copyWith(checked: false, updatedAt: now);
      }
    }
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    await load();
    if (newIndex > oldIndex) newIndex--;
    final ShoppingListItem item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    await _renumberAndPersist();
  }

  Future<void> _update(
    String id,
    ShoppingListItem Function(ShoppingListItem item) update,
  ) async {
    await load();
    final int index = _items.indexWhere((ShoppingListItem item) => item.id == id);
    if (index < 0) return;
    _items[index] = update(_items[index]);
    await _persist();
  }

  Future<void> _renumberAndPersist() async {
    for (int index = 0; index < _items.length; index++) {
      _items[index] = _items[index].copyWith(sortOrder: index);
    }
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.save(_items);
    notifyListeners();
  }

  static String _normalize(String value) => value.trim().toLowerCase();
  static String? _optional(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
