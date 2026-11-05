import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_match/data/models/couple_filter_state.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/services/api_service.dart';

void main() {
  test('filter save and confirmation carry the same session and round', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode({
        'sessionId': 'pair-a', 'generation': 3,
        'myChoices': {'confirmed': request.url.path.endsWith('confirm')},
        'bothConfirmed': false, 'compatibility': 0, 'status': 'draft',
      }), 200, headers: {'content-type': 'application/json'});
    });
    addTearDown(client.close);
    final repository = CoupleRepository(ApiService(client: client, accessTokenProvider: () => 'test-token'));
    final saved = await repository.updateMyFilterState(
      const CoupleFilterChoices(dishRegisters: ['main']), sessionId: 'pair-a', generation: 2,
    );
    await repository.confirmMyFilterState(sessionId: saved.sessionId, generation: saved.generation);
    expect(bodies[0]['sessionId'], 'pair-a');
    expect(bodies[0]['generation'], 2);
    expect(bodies[1], {'sessionId': 'pair-a', 'generation': 3});
  });

  test('restart and leave retain their originating session', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response('{}', 200, headers: {'content-type': 'application/json'});
    });
    addTearDown(client.close);
    final repository = CoupleRepository(ApiService(client: client, accessTokenProvider: () => 'test-token'));
    await repository.requestDeckRestart(sessionId: 'old-pair');
    await repository.leave(sessionId: 'old-pair');
    expect(bodies, [{'sessionId': 'old-pair'}, {'sessionId': 'old-pair'}]);
  });
}
