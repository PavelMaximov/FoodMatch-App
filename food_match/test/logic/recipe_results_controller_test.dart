import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/features/recipes/logic/recipe_results_controller.dart';
import '../helpers/dish_test_data.dart';

PaginatedDishesResult page(String id, {int offset = 0, bool more = false}) =>
    PaginatedDishesResult(items: [buildTestDish(id: id, name: id)],
      total: 100, limit: 1, offset: offset, hasMore: more);

void main() {
  test('replacing query during pagination releases the old loading lock', () async {
    final requests = <Completer<PaginatedDishesResult>>[];
    final controller = RecipeResultsController(fetchPage: ({required offset, force = false}) {
      final request = Completer<PaginatedDishesResult>();
      requests.add(request);
      return request.future;
    });
    final initial = controller.reload();
    requests[0].complete(page('a', more: true));
    await initial;
    final oldMore = controller.loadMore();
    final replacement = controller.reload();
    requests[2].complete(page('b', more: true));
    await replacement;
    expect(controller.isLoadingMore, isFalse);
    final next = controller.loadMore();
    expect(requests, hasLength(4));
    requests[1].complete(page('stale', offset: 1));
    await oldMore;
    expect(controller.isLoadingMore, isTrue);
    requests[3].complete(page('c', offset: 1));
    await next;
    expect(controller.items.map((dish) => dish.id), ['b', 'c']);
    controller.dispose();
  });

  test('post-filter skips pages with no visible dishes', () async {
    final offsets = <int>[];
    final controller = RecipeResultsController(
      postFilter: (dish) => dish.id == 'visible',
      fetchPage: ({required offset, force = false}) async {
        offsets.add(offset);
        return page(offset == 0 ? 'hidden' : 'visible', offset: offset, more: offset == 0);
      });
    await controller.reload();
    expect(offsets, [0, 1]);
    expect(controller.items.single.id, 'visible');
    expect(controller.hasMore, isFalse);
    controller.dispose();
  });

  test('an empty server page cannot cause an endless pagination loop', () async {
    var calls = 0;
    final controller = RecipeResultsController(fetchPage: ({required offset, force = false}) async {
      calls++;
      return PaginatedDishesResult(items: [], total: 10, limit: 20, offset: offset, hasMore: true);
    });
    await controller.reload();
    expect(calls, 1);
    expect(controller.hasMore, isFalse);
    controller.dispose();
  });

  test('late completion after dispose does not notify or apply', () async {
    final request = Completer<PaginatedDishesResult>();
    final controller = RecipeResultsController(fetchPage: ({required offset, force = false}) => request.future);
    final loading = controller.reload();
    controller.dispose();
    request.complete(page('late'));
    await loading;
    expect(controller.items, isEmpty);
  });

  test('pagination error retains items and can retry', () async {
    var calls = 0;
    final controller = RecipeResultsController(fetchPage: ({required offset, force = false}) async {
      calls++;
      if (calls == 2) throw StateError('offline');
      return page(offset == 0 ? 'a' : 'b', offset: offset, more: offset == 0);
    });
    await controller.reload();
    await controller.loadMore();
    expect(controller.items.single.id, 'a');
    expect(controller.loadMoreError, isNotNull);
    await controller.loadMore();
    expect(controller.items.map((dish) => dish.id), ['a', 'b']);
    expect(controller.loadMoreError, isNull);
    controller.dispose();
  });
}
