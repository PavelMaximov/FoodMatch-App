import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/dishes/logic/custom_dishes_controller.dart';
import '../helpers/dish_test_data.dart';

class FakeCustomRepository extends DishRepository {
  FakeCustomRepository() : super(ApiService());
  List<Dish> items = [buildTestDish(id: 'a', name: 'A'), buildTestDish(id: 'b', name: 'B')];
  final deleted = <String>[];
  bool failLoad = false;
  bool failDelete = false;
  @override
  Future<List<Dish>> getMyCustomDishes() async {
    if (failLoad) throw StateError('offline');
    return List.of(items);
  }
  @override
  Future<void> deleteMyDish(String dishId) async {
    deleted.add(dishId);
    if (failDelete) throw StateError('offline');
    items.removeWhere((dish) => dish.id == dishId);
  }
}

void main() {
  test('refresh failure keeps loaded dishes and reports an error', () async {
    final repository = FakeCustomRepository();
    final controller = CustomDishesController(repository);
    await controller.load();
    repository.failLoad = true;
    await controller.load();
    expect(controller.dishes, hasLength(2));
    expect(controller.error, isNotNull);
    controller.dispose();
  });

  testWidgets('Undo restores order and cancels the delayed delete', (tester) async {
    final repository = FakeCustomRepository();
    final controller = CustomDishesController(repository);
    await controller.load();
    controller.deleteDish(controller.dishes.first);
    controller.undoDeleteDish('a');
    await tester.pump(const Duration(seconds: 7));
    expect(controller.dishes.map((dish) => dish.id), ['a', 'b']);
    expect(repository.deleted, isEmpty);
    controller.dispose();
  });

  testWidgets('failed delete restores card and reports once', (tester) async {
    final repository = FakeCustomRepository()..failDelete = true;
    final errors = <String>[];
    final controller = CustomDishesController(repository, onDeleteError: errors.add);
    await controller.load();
    controller.deleteDish(controller.dishes.first);
    await tester.pump(const Duration(seconds: 7));
    expect(repository.deleted, ['a']);
    expect(controller.dishes.map((dish) => dish.id), ['a', 'b']);
    expect(errors, hasLength(1));
    controller.dispose();
  });

  testWidgets('leaving the route commits pending delete only once', (tester) async {
    final repository = FakeCustomRepository();
    final controller = CustomDishesController(repository);
    await controller.load();
    controller.deleteDish(controller.dishes.first);
    controller.dispose();
    await tester.pump(const Duration(seconds: 7));
    expect(repository.deleted, ['a']);
  });
}
