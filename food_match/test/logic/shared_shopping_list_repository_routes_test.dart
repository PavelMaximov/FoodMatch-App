import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/shopping_list/data/shared_shopping_list_repository.dart';

void main() {
  final operations =
      <String, Future<void> Function(SharedShoppingListRepository)>{
        'GET /api/shopping-list/shared': (repository) async {
          await repository.load();
        },
        'POST /api/shopping-list/shared/items': (repository) async {
          await repository.add(name: 'Tomato');
        },
        'PATCH /api/shopping-list/shared/items/item': (repository) async {
          await repository.setChecked('item', true);
        },
        'DELETE /api/shopping-list/shared/items/item': (repository) async {
          await repository.remove('item');
        },
        'PATCH /api/shopping-list/shared/reorder': (repository) async {
          await repository.reorder(['item']);
        },
      };
  for (final operation in operations.entries) {
    test('shared repository requests ${operation.key}', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect('${request.method} ${request.url.path}', operation.key);
        return http.Response(
          '{"sessionId":"pair","items":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);
      await operation.value(
        SharedShoppingListRepository(
          ApiService(client: client, accessTokenProvider: () => 'test-token'),
        ),
      );
      expect(requests, 1);
    });
  }
}
