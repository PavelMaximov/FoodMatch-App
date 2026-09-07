import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/models/match_item.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';
import 'package:food_match/shell/logic/nav_badge_animation_controller.dart';

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

  test('first Solo swipe match updates badge state once', () {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-new');
    final NavBadgeAnimationController animation = NavBadgeAnimationController();

    final bool first = provider.recordSoloMatchFromSwipe(
      dish: dishes.first,
      sessionId: 'solo-new',
      eventId: 'swipe-1',
    );
    if (first) {
      animation.showSoloMatchesPlusOne(
        eventKey: 'solo:solo-new:swipe-1',
      );
    }

    expect(first, isTrue);
    expect(provider.matchCount, 1);
    expect(animation.soloMatchesPlusOneEvent, 1);
    expect(
      provider.recordSoloMatchFromSwipe(
        dish: dishes.first,
        sessionId: 'solo-new',
        eventId: 'swipe-1',
      ),
      isFalse,
    );
    expect(
      animation.showSoloMatchesPlusOne(
        eventKey: 'solo:solo-new:swipe-1',
      ),
      isFalse,
    );
    expect(animation.soloMatchesPlusOneEvent, 1);
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
