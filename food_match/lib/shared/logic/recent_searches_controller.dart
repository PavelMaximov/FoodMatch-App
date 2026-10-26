import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A local search history. User edits win over a delayed initial disk read.
class RecentSearchesController extends ChangeNotifier {
  RecentSearchesController(this.storageKey);
  final String storageKey;
  List<String> _items = const [];
  List<String> get items => _items;
  int _revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  Future<void> load() async {
    final revision = _revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_disposed || revision != _revision) return;
      _items = List.unmodifiable(preferences.getStringList(storageKey) ?? []);
      notifyListeners();
    } catch (_) {
      // History is optional; a storage failure must not block recipe search.
    }
  }

  Future<void> remember(String value) {
    final query = value.trim();
    if (_disposed || query.isEmpty) return Future.value();
    return _replace([query, ..._items.where((item) => item.toLowerCase() != query.toLowerCase())].take(10).toList());
  }

  Future<void> clear() => _disposed ? Future.value() : _replace([]);

  Future<void> _replace(List<String> values) {
    _revision++;
    _items = List.unmodifiable(values);
    notifyListeners();
    final snapshot = List<String>.of(values);
    _writes = _writes.then((_) async {
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setStringList(storageKey, snapshot);
      } catch (_) {
        // Preserve the usable in-memory history if local storage is unavailable.
      }
    });
    return _writes;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
