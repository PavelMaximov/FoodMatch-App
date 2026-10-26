import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/services/api_service.dart';

import '../../helpers/dish_test_data.dart';

void main() {
  test(
    'invalidation rejects old response and does not clear newer in-flight load',
    () async {
      final api = _Api();
      final repo = DishRepository(api);
      final old = repo.getCatalogDishes();
      final rejected = expectLater(old, throwsStateError);
      repo.handleAuthBoundary(1);
      final fresh = repo.getCatalogDishes();
      api.requests[0].complete({
        'dishes': [buildTestDish(id: 'old', name: 'Old').toJson()],
      });
      await rejected;
      final joined = repo.getCatalogDishes();
      expect(api.requests, hasLength(2));
      api.requests[1].complete({
        'dishes': [buildTestDish(id: 'new', name: 'New').toJson()],
      });
      expect((await fresh).single.id, 'new');
      expect((await joined).single.id, 'new');
      expect((await repo.getCatalogDishes()).single.id, 'new');
      expect(api.requests, hasLength(2));
    },
  );

  test('all concurrent callers receive the same stale fallback', () async {
    final api = _Api();
    final repo = DishRepository(api);
    final initial = repo.getCatalogDishes();
    api.requests.single.complete({
      'dishes': [buildTestDish(id: 'a', name: 'A').toJson()],
    });
    await initial;
    final first = repo.getCatalogDishes(force: true);
    final second = repo.getCatalogDishes(force: true);
    api.requests.last.completeError(StateError('offline'));
    expect((await first).single.id, 'a');
    expect((await second).single.id, 'a');
    expect(api.requests, hasLength(2));
  });

  test('empty catalog is cached and invalidation allows retry', () async {
    final api = _Api();
    final repo = DishRepository(api);
    final initial = repo.getCatalogDishes();
    api.requests.single.complete({'dishes': []});
    await initial;
    expect(await repo.getCatalogDishes(), isEmpty);
    expect(api.requests, hasLength(1));
    repo.invalidateCatalogCache();
    final next = repo.getCatalogDishes();
    api.requests.last.complete({'dishes': []});
    await next;
    expect(api.requests, hasLength(2));
  });
}

class _Api extends ApiService {
  final requests = <Completer<dynamic>>[];
  @override
  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) {
    final request = Completer<dynamic>();
    requests.add(request);
    return request.future;
  }
}
