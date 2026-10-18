import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_match/data/local/cache_service.dart';

void main() {
  setUp(() { SharedPreferences.setMockInitialValues({}); });

  test('acknowledging one swipe preserves unsent and concurrently queued entries', () async {
    final cache = CacheService();
    await cache.queueSwipe('first', 'like', userId: 'a', mode: 'solo', sessionId: 'solo-a');
    await cache.queueSwipe('second', 'dislike', userId: 'a', mode: 'solo', sessionId: 'solo-a');
    final first = (await cache.getPendingSwipes()).first;
    await Future.wait([
      cache.acknowledgeSwipe(first['id'] as String),
      CacheService().queueSwipe('third', 'like', userId: 'b', mode: 'paired', sessionId: 'pair-b'),
    ]);
    final pending = await cache.getPendingSwipes();
    expect(pending.map((e) => e['dishId']), ['second', 'third']);
    expect(pending.first['userId'], 'a');
    expect(pending.first['sessionId'], 'solo-a');
    expect(pending.last['mode'], 'paired');
    expect(pending.last['userId'], 'b');
  });
}
