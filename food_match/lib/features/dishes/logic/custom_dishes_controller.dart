import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/errors/error_messages.dart';
import '../../../data/models/dish.dart';
import '../../../data/repositories/dish_repository.dart';
import '../../../data/services/api_service.dart';

class _PendingDeletedDish {
  _PendingDeletedDish({
    required this.dish,
    required this.index,
    required this.repository,
  });

  final Dish dish;
  int index;
  final DishRepository repository;
  Timer? timer;
  bool isCommitted = false;
}

class CustomDishesController extends ChangeNotifier {
  CustomDishesController(this._repository, {this.onChanged, this.onDeleteError});
  final DishRepository _repository;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onDeleteError;
  final Map<String, _PendingDeletedDish> _pendingDeletedDishes = {};
  List<Dish> _myDishes = [];
  List<Dish> get dishes => List.unmodifiable(_myDishes);
  bool isLoading = false;
  String? error;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load() async {
    if (_disposed) return;
    final generation = ++_generation;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final dishes = await _repository.getMyCustomDishes();
      if (_disposed || generation != _generation) return;
      _myDishes = dishes.where((dish) => !_pendingDeletedDishes.containsKey(dish.id)).toList();
    } catch (exception) {
      if (_disposed || generation != _generation) return;
      error = ErrorMessages.fromException(exception);
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  bool deleteDish(Dish dish) {
    if (_disposed || _pendingDeletedDishes.containsKey(dish.id)) return false;

    final int index = _myDishes.indexWhere(
      (Dish currentDish) => currentDish.id == dish.id,
    );
    if (index < 0) return false;

    int originalIndex = index;
    final pendingInOrder = _pendingDeletedDishes.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final pendingDelete in pendingInOrder) {
      if (pendingDelete.index <= originalIndex) originalIndex++;
    }

    final _PendingDeletedDish pendingDelete = _PendingDeletedDish(
      dish: dish,
      index: originalIndex,
      repository: _repository,
    );
    _pendingDeletedDishes[dish.id] = pendingDelete;
    pendingDelete.timer = Timer(
      const Duration(seconds: 6),
      () => _commitPendingDelete(dish.id),
    );

    _myDishes.removeAt(index);
    notifyListeners();

    return true;
  }

  void undoDeleteDish(String dishId) {
    if (_disposed) return;
    final pendingDelete = _pendingDeletedDishes[dishId];
    if (pendingDelete == null || pendingDelete.isCommitted) return;
    _pendingDeletedDishes.remove(dishId);

    pendingDelete.timer?.cancel();
    if (_disposed || _myDishes.any((Dish dish) => dish.id == dishId)) return;

    final int safeIndex = _visibleIndexFor(pendingDelete);
    _myDishes.insert(safeIndex, pendingDelete.dish);
    notifyListeners();
  }

  Future<void> _commitPendingDelete(String dishId) async {
    final _PendingDeletedDish? pendingDelete = _pendingDeletedDishes[dishId];
    if (pendingDelete == null || pendingDelete.isCommitted) return;

    pendingDelete.isCommitted = true;
    pendingDelete.timer?.cancel();
    try {
      await pendingDelete.repository.deleteMyDish(dishId);
      _generation++;
      isLoading = false;
      _pendingDeletedDishes.remove(dishId);
      for (final _PendingDeletedDish other in _pendingDeletedDishes.values) {
        if (other.index > pendingDelete.index) other.index--;
      }
      if (!_disposed) {
        notifyListeners();
        onChanged?.call();
      }
    } on ApiException catch (e) {
      _rollbackFailedDelete(
        pendingDelete,
        ErrorMessages.fromApiException(e, fallback: 'Please try again.'),
      );
    } catch (_) {
      _rollbackFailedDelete(pendingDelete, 'Please try again.');
    }
  }

  void _rollbackFailedDelete(
    _PendingDeletedDish pendingDelete,
    String message,
  ) {
    _pendingDeletedDishes.remove(pendingDelete.dish.id);
    if (_disposed) return;

    if (!_myDishes.any((Dish dish) => dish.id == pendingDelete.dish.id)) {
      final int safeIndex = _visibleIndexFor(pendingDelete);
      _myDishes.insert(safeIndex, pendingDelete.dish);
      notifyListeners();
    }
    onDeleteError?.call(message);
  }

  Future<void> _commitDeleteAfterDispose(
    _PendingDeletedDish pendingDelete,
  ) async {
    if (pendingDelete.isCommitted) return;
    pendingDelete.isCommitted = true;
    try {
      await pendingDelete.repository.deleteMyDish(pendingDelete.dish.id);
    } catch (_) {
      // A failed delete remains on the backend and will reappear on the next load.
    }
  }

  int _visibleIndexFor(_PendingDeletedDish pendingDelete) {
    final int hiddenBefore = _pendingDeletedDishes.values
        .where((_PendingDeletedDish other) => other.index < pendingDelete.index)
        .length;
    final int visibleIndex = pendingDelete.index - hiddenBefore;
    return visibleIndex.clamp(0, _myDishes.length).toInt();
  }


  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final pending = _pendingDeletedDishes.values.toList();
    _pendingDeletedDishes.clear();
    for (final deletion in pending) {
      deletion.timer?.cancel();
      unawaited(_commitDeleteAfterDispose(deletion));
    }
    super.dispose();
  }
}
