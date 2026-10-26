import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/match_item.dart';

import '../../helpers/dish_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final match = MatchItem(
    id: 'match',
    dish: buildTestDish(id: 'dish', name: 'Dish'),
    mode: 'paired',
    matchType: 'pair_match',
    sessionId: 'session',
    coupleId: 'couple',
    createdAt: DateTime.utc(2026, 10, 25),
  );

  test(
    'match snapshot preserves metadata and isolates account/session scopes',
    () async {
      final cache = CacheService();
      await cache.cacheMatchItems([match], scopeKey: 'user-a:pair-a');
      final restored = (await cache.getCachedMatchItems(
        scopeKey: 'user-a:pair-a',
      )).single;
      expect(restored.toJson(), match.toJson());
      expect(
        await cache.getCachedMatchItems(scopeKey: 'user-b:pair-a'),
        isEmpty,
      );
      expect(
        await cache.getCachedMatchItems(scopeKey: 'user-a:pair-b'),
        isEmpty,
      );
    },
  );

  test(
    'clear is ordered after pending writes across cache instances',
    () async {
      final first = CacheService().cacheMatchItems([match], scopeKey: 'old');
      final clear = CacheService().clearCachedMatches();
      final second = CacheService().cacheMatchItems([match], scopeKey: 'new');
      await Future.wait([first, clear, second]);
      expect(
        await CacheService().getCachedMatchItems(scopeKey: 'old'),
        isEmpty,
      );
      expect(
        await CacheService().getCachedMatchItems(scopeKey: 'new'),
        hasLength(1),
      );
      await CacheService().clearAuthBoundaryTransient();
      expect(
        await CacheService().getCachedMatchItems(scopeKey: 'new'),
        isEmpty,
      );
    },
  );

  test(
    'malformed timestamps and old dish-only cache are cache misses',
    () async {
      SharedPreferences.setMockInitialValues({
        'cached_match_snapshot_v2':
            '{"scope":"user","cachedAt":"bad","items":[]}',
        'cached_matches': '[]',
        'matches_cached_at': 'bad',
        'cached_dishes': '[]',
        'dishes_cached_at': 'bad',
      });
      expect(
        await CacheService().getCachedMatchItems(scopeKey: 'user'),
        isEmpty,
      );
      expect(await CacheService().getCachedDishes(), isEmpty);
    },
  );
}
