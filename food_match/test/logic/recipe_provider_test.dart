import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/dishes/logic/recipe_provider.dart';

import '../helpers/dish_test_data.dart';

void main() {
  test('keeps the newest recipe when an older response finishes last', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final RecipeProvider provider = RecipeProvider(repository: repository);
    final Future<void> loadA = provider.loadRecipeForDish(dishId: 'a');
    final Future<void> loadB = provider.loadRecipeForDish(dishId: 'b');

    repository.requests['b']!.complete(buildTestDish(id: 'b', name: 'B'));
    await loadB;
    repository.requests['a']!.complete(buildTestDish(id: 'a', name: 'A'));
    await loadA;

    expect(provider.currentDish?.id, 'b');
    expect(provider.error, isNull);
  });

  test('ignores an error from an older recipe request', () async {
    final _FakeDishRepository repository = _FakeDishRepository();
    final RecipeProvider provider = RecipeProvider(repository: repository);
    final Future<void> loadA = provider.loadRecipeForDish(dishId: 'a');
    final Future<void> loadB = provider.loadRecipeForDish(dishId: 'b');

    repository.requests['b']!.complete(buildTestDish(id: 'b', name: 'B'));
    await loadB;
    repository.requests['a']!.completeError(const ApiException('old error'));
    await loadA;

    expect(provider.currentDish?.id, 'b');
    expect(provider.error, isNull);
  });
}

class _FakeDishRepository extends DishRepository {
  _FakeDishRepository() : super(ApiService());

  final Map<String, Completer<Dish>> requests = <String, Completer<Dish>>{};

  @override
  Future<Dish> getDishById(String dishId) {
    final Completer<Dish> completer = Completer<Dish>();
    requests[dishId] = completer;
    return completer.future;
  }
}
