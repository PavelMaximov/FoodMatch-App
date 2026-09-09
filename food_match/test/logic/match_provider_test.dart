import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/match_item.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';
import 'package:food_match/shell/logic/match_badge_controller.dart';

import '../helpers/dish_test_data.dart';

void main() {
  late MatchProvider provider;
  late _FakeSwipeRepository fakeRepo;
  late _FakeCacheService fakeCacheService;
  late MatchBadgeController badgeController;

  final List<Dish> dishes = <Dish>[
    buildTestDish(id: '1', name: 'Borscht', description: 'Soup'),
  ];

  setUp(() {
    fakeRepo = _FakeSwipeRepository()
      ..matches = dishes
          .map((Dish dish) => MatchItem(dish: dish, mode: 'paired', matchType: 'pair_match'))
          .toList();
    fakeCacheService = _FakeCacheService();
    badgeController = MatchBadgeController();
    provider = MatchProvider(
      swipeRepository: fakeRepo,
      cacheService: fakeCacheService,
      badgeController: badgeController,
    );
  });

  test('loadMatches loads current couple matches', () async {
    provider.setActiveUser('user-a');
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

  test('first Solo swipe match updates badge state once', () {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-new');
    final bool first = provider.recordSoloMatchFromSwipe(
      dish: dishes.first,
      sessionId: 'solo-new',
      eventId: 'swipe-1',
    );
    final bool badgeRegistered = badgeController.registerNewMatch(
      matchId: 'match-1',
      source: 'test',
      mode: 'solo',
      sessionId: 'solo-new',
    );

    expect(first, isTrue);
    expect(badgeRegistered, isTrue);
    expect(provider.matchCount, 1);
    expect(badgeController.badgeCount, 1);
    expect(badgeController.bumpToken, 1);
    expect(
      provider.recordSoloMatchFromSwipe(
        dish: dishes.first,
        sessionId: 'solo-new',
        eventId: 'swipe-1',
      ),
      isFalse,
    );
    expect(
      badgeController.registerNewMatch(
        matchId: 'match-1',
        source: 'test',
        mode: 'solo',
        sessionId: 'solo-new',
      ),
      isFalse,
    );
    expect(badgeController.bumpToken, 1);
  });

  test('new Solo session clears optimistic badge count', () {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    provider.recordSoloMatchFromSwipe(
      dish: dishes.first,
      sessionId: 'solo-a',
      eventId: 'swipe-a',
    );
    expect(provider.matchCount, 1);

    provider.setSoloSession('solo-b');

    expect(provider.matchCount, 0);
    expect(
      provider.recordSoloMatchFromSwipe(
        dish: dishes.first,
        sessionId: 'solo-a',
        eventId: 'late-swipe',
      ),
      isFalse,
    );
  });

  test('Solo refresh reconciles optimistic match without double count', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-new');
    provider.recordSoloMatchFromSwipe(
      dish: dishes.first,
      sessionId: 'solo-new',
      eventId: 'swipe-1',
    );
    fakeRepo.matches = <MatchItem>[
      MatchItem(
        id: 'server-match-1',
        dish: dishes.first,
        mode: 'solo',
        matchType: 'solo_pick',
        sessionId: 'solo-new',
      ),
    ];

    await provider.loadMatches(
      force: true,
      mode: 'solo',
      soloSessionId: 'solo-new',
    );

    expect(provider.matchCount, 1);
    expect(provider.matches.single.id, 'server-match-1');
    expect(badgeController.badgeCount, 1);
    expect(badgeController.bumpToken, 0);
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
