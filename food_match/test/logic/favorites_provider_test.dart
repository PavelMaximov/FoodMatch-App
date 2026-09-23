import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/favorites/logic/favorites_provider.dart';

import '../helpers/dish_test_data.dart';

void main() {
  test('ignores a stale load response after the active user changes', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    final Dish dishB = buildTestDish(id: 'b', name: 'B');

    provider.setActiveUser('user-a');
    provider.setActiveUser('user-b');
    repository.loads[1].complete(<Dish>[dishB]);
    await repository.loads[1].future;
    await Future<void>.delayed(Duration.zero);
    repository.loads[0].complete(<Dish>[dishA]);
    await repository.loads[0].future;
    await Future<void>.delayed(Duration.zero);

    expect(provider.savedDishIds, <String>{'b'});
  });

  test('failed toggle rolls back only its own dish', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    final Dish dishB = buildTestDish(id: 'b', name: 'B');
    provider.setActiveUser('user');
    repository.loads.single.complete(<Dish>[]);
    await Future<void>.delayed(Duration.zero);

    final Future<void> toggleA = provider.toggleFavorite(dishA);
    final Future<void> toggleB = provider.toggleFavorite(dishB);
    repository.saves['a']!.complete();
    repository.saves['b']!.completeError(const ApiException('failed'));
    await toggleA;
    await toggleB;

    expect(provider.savedDishIds, <String>{'a'});
  });
}

class _FakeDishRepository extends DishRepository {
  _FakeDishRepository() : super(ApiService());

  final List<Completer<List<Dish>>> loads = <Completer<List<Dish>>>[];
  final Map<String, Completer<void>> saves = <String, Completer<void>>{};

  @override
  Future<List<Dish>> getSavedDishes() {
    final Completer<List<Dish>> completer = Completer<List<Dish>>();
    loads.add(completer);
    return completer.future;
  }

  @override
  Future<void> saveDish(String dishId) {
    final Completer<void> completer = Completer<void>();
    saves[dishId] = completer;
    return completer.future;
  }
}
