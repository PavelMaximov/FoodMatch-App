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

  test('pending load does not remove a successfully added favorite', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    provider.setActiveUser('user');

    final Future<void> toggle = provider.toggleFavorite(dishA);
    repository.saves['a']!.complete();
    await toggle;
    repository.loads.single.complete(<Dish>[]);
    await Future<void>.delayed(Duration.zero);

    expect(provider.savedDishIds, <String>{'a'});
  });

  test('pending load does not restore a successfully removed favorite', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    provider.setActiveUser('user');
    provider.toggleFavorite(dishA);
    repository.saves['a']!.complete();
    await Future<void>.delayed(Duration.zero);

    final Future<void> remove = provider.toggleFavorite(dishA);
    repository.unsaves['a']!.complete();
    await remove;
    repository.loads.single.complete(<Dish>[dishA]);
    await Future<void>.delayed(Duration.zero);

    expect(provider.savedDishIds, isEmpty);
  });

  test('failed add during load reverts only that dish', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    final Dish dishB = buildTestDish(id: 'b', name: 'B');
    provider.setActiveUser('user');
    final Future<void> a = provider.toggleFavorite(dishA);
    final Future<void> b = provider.toggleFavorite(dishB);
    repository.saves['a']!.completeError(const ApiException('failed'));
    repository.saves['b']!.complete();
    await Future.wait(<Future<void>>[a, b]);
    repository.loads.single.complete(<Dish>[]);
    await Future<void>.delayed(Duration.zero);
    expect(provider.savedDishIds, <String>{'b'});
  });

  test('failed remove during load restores only that dish', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    final Dish dishB = buildTestDish(id: 'b', name: 'B');
    provider.setActiveUser('user');
    repository.loads.single.complete(<Dish>[dishA]);
    await Future<void>.delayed(Duration.zero);
    final Future<void> remove = provider.toggleFavorite(dishA);
    final Future<void> add = provider.toggleFavorite(dishB);
    repository.unsaves['a']!.completeError(const ApiException('failed'));
    repository.saves['b']!.complete();
    await Future.wait(<Future<void>>[remove, add]);
    expect(provider.savedDishIds, <String>{'a', 'b'});
  });

  test('user switch invalidates stale toggle completion', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final FavoritesProvider provider = FavoritesProvider(repository: repository);
    final Dish dishA = buildTestDish(id: 'a', name: 'A');
    provider.setActiveUser('old');
    final Future<void> toggle = provider.toggleFavorite(dishA);
    provider.setActiveUser('new');
    repository.loads[1].complete(<Dish>[]);
    repository.saves['a']!.complete();
    await toggle;
    await Future<void>.delayed(Duration.zero);
    expect(provider.savedDishIds, isEmpty);
  });
}

class _FakeDishRepository extends DishRepository {
  _FakeDishRepository() : super(ApiService());

  final List<Completer<List<Dish>>> loads = <Completer<List<Dish>>>[];
  final Map<String, Completer<void>> saves = <String, Completer<void>>{};
  final Map<String, Completer<void>> unsaves = <String, Completer<void>>{};

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

  @override
  Future<void> unsaveDish(String dishId) {
    final Completer<void> completer = Completer<void>();
    unsaves[dishId] = completer;
    return completer.future;
  }
}
