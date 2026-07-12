import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/match_item.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';

import '../helpers/dish_test_data.dart';

void main() {
  late MatchProvider provider;
  late _FakeSwipeRepository fakeRepo;
  late _FakeCacheService fakeCacheService;

  final List<Dish> dishes = <Dish>[
    buildTestDish(id: '1', name: 'Borscht', description: 'Soup'),
  ];

  setUp(() {
    fakeRepo = _FakeSwipeRepository()
      ..matches = dishes
          .map((Dish dish) => MatchItem(dish: dish, mode: 'paired', matchType: 'pair_match'))
          .toList();
    fakeCacheService = _FakeCacheService();
    provider = MatchProvider(
      swipeRepository: fakeRepo,
      cacheService: fakeCacheService,
    );
  });

  test('loadMatches loads current couple matches', () async {
    provider.setActiveCouple('couple-1');
    await provider.loadMatches();

    expect(provider.matchCount, 1);
    expect(provider.matches.first.dish.name, 'Borscht');
    expect(fakeCacheService.cachedMatches, dishes);
  });

  test('clearMatches clears matches', () {
    provider.matches = dishes
        .map((Dish dish) => MatchItem(dish: dish, mode: 'paired', matchType: 'pair_match'))
        .toList();

    provider.clearMatches();

    expect(provider.matches, isEmpty);
    expect(fakeCacheService.wasCleared, isTrue);
  });
}

class _FakeSwipeRepository extends SwipeRepository {
  _FakeSwipeRepository() : super(ApiService());

  List<MatchItem> matches = <MatchItem>[];

  @override
  Future<List<MatchItem>> getMatches({
    String mode = 'all',
    String? scope,
    String? soloSessionId,
  }) async => matches;
}

class _FakeCacheService extends CacheService {
  List<Dish> cachedMatches = <Dish>[];
  bool wasCleared = false;

  @override
  Future<void> cacheMatches(List<Dish> matches, {String? coupleId}) async {
    cachedMatches = matches;
  }

  @override
  Future<List<Dish>> getCachedMatches({String? coupleId}) async => <Dish>[];

  @override
  Future<void> clearCachedMatches() async {
    wasCleared = true;
  }
}
