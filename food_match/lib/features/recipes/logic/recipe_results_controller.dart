import 'package:flutter/foundation.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';

typedef RecipePageLoader = Future<PaginatedDishesResult> Function({
  required int offset,
  bool force,
});

/// Owns one query's pagination; a replacement query invalidates all older pages.
class RecipeResultsController extends ChangeNotifier {
  RecipeResultsController({required this.fetchPage, this.postFilter});

  final RecipePageLoader fetchPage;
  final bool Function(Dish)? postFilter;
  List<Dish> _items = const [];
  List<Dish> get items => _items;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = false;
  String? error;
  String? loadMoreError;
  int _offset = 0;
  int _generation = 0;
  bool _disposed = false;

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void invalidateQuery() {
    if (_disposed) return;
    _generation++;
    isLoading = true;
    isLoadingMore = false;
    hasMore = false;
    notifyListeners();
  }

  Future<void> reload({bool force = false}) async {
    if (_disposed) return;
    final generation = ++_generation;
    isLoading = true;
    isLoadingMore = false;
    error = null;
    loadMoreError = null;
    hasMore = false;
    _offset = 0;
    _items = const [];
    notifyListeners();
    await _load(generation, first: true, force: force);
  }

  Future<void> loadMore() async {
    if (_disposed || isLoading || isLoadingMore || !hasMore) return;
    final generation = _generation;
    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    await _load(generation, first: false);
  }

  Future<void> _load(int generation, {required bool first, bool force = false}) async {
    try {
      // A post-filter can consume a complete server page. Keep advancing until
      // there is visible content or the server is exhausted.
      while (_isCurrent(generation)) {
        final previousOffset = _offset;
        final page = await fetchPage(offset: previousOffset, force: force);
        if (!_isCurrent(generation)) return;
        final ids = _items.map((dish) => dish.id).toSet();
        final additions = page.items.where((dish) =>
          (postFilter?.call(dish) ?? true) && ids.add(dish.id)).toList();
        _items = List.unmodifiable([..._items, ...additions]);
        _offset = page.offset + page.items.length;
        hasMore = page.hasMore && _offset > previousOffset;
        if (additions.isNotEmpty || !hasMore) break;
      }
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      final message = ErrorMessages.fromException(exception);
      if (first) {
        error = message;
      } else {
        loadMoreError = message;
      }
    } finally {
      if (_isCurrent(generation)) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
