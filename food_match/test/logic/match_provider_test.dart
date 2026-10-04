import 'dart:async';

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

  test('forced refresh burst shares one follow-up request', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.holdRequests = true;
    final initial = provider.loadMatches();
    final first = provider.loadMatches(force: true);
    final second = provider.loadMatches(force: true);
    expect(identical(first, second), isTrue);
    expect(fakeRepo.requests, hasLength(1));
    fakeRepo.requests.first.complete(<MatchItem>[]);
    await initial;
    await Future<void>.delayed(Duration.zero);
    expect(fakeRepo.requests, hasLength(2));
    fakeRepo.requests.last.complete(<MatchItem>[]);
    await Future.wait([first, second]);
    expect(fakeRepo.requests, hasLength(2));
    expect(provider.isLoading, isFalse);
  });

  test('old queued refresh cannot restore a previous session', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.holdRequests = true;
    final initial = provider.loadMatches();
    final queued = provider.loadMatches(force: true, soloSessionId: 'solo-a');
    provider.setSoloSession('solo-b');
    fakeRepo.requests.single.complete(<MatchItem>[]);
    await Future.wait([initial, queued]);
    expect(provider.activeSoloSessionId, 'solo-b');
    expect(fakeRepo.requests, hasLength(1));
  });

  test('returning to the same session does not revive an old response', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.holdRequests = true;
    final old = provider.loadMatches();
    provider.setSoloSession('solo-b');
    provider.setSoloSession('solo-a');
    final fresh = provider.loadMatches();
    fakeRepo.requests.first.complete(<MatchItem>[
      MatchItem(id: 'stale', dish: dishes.first, mode: 'solo',
          matchType: 'solo_pick', sessionId: 'solo-a'),
    ]);
    await old;
    expect(provider.matches, isEmpty);
    expect(provider.isLoading, isTrue);
    fakeRepo.requests.last.complete(<MatchItem>[]);
    await fresh;
    expect(provider.isLoading, isFalse);
  });

  test('account change during cache write cannot update the new badge', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.matches = <MatchItem>[
      MatchItem(id: 'old-match', dish: dishes.first, mode: 'solo',
          matchType: 'solo_pick', sessionId: 'solo-a'),
    ];
    fakeCacheService.writeGate = Completer<void>();
    final request = provider.loadMatches();
    await Future<void>.delayed(Duration.zero);
    provider.setActiveUser('user-b');
    fakeCacheService.writeGate!.complete();
    await request;
    expect(provider.matches, isEmpty);
    expect(badgeController.badgeCount, 0);
  });

  test('late cache fallback cannot populate a different session', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.holdRequests = true;
    fakeCacheService.readGate = Completer<List<Dish>>();
    final request = provider.loadMatches();
    fakeRepo.requests.single.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    provider.setSoloSession('solo-b');
    fakeCacheService.readGate!.complete(dishes);
    await request;
    expect(provider.matches, isEmpty);
    expect(provider.error, isNull);
  });

  test('paired notification response is ignored after switching to Solo', () async {
    provider.setActiveUser('user-a');
    provider.setActiveCouple('pair-a');
    await provider.loadMatches();
    fakeRepo.holdRequests = true;
    final request = provider.syncPairedMatchesForNotifications();
    provider.setSoloSession('solo-b');
    fakeRepo.requests.single.complete(<MatchItem>[
      MatchItem(id: 'old-pair', dish: dishes.first, mode: 'paired',
          matchType: 'pair_match', sessionId: 'pair-a'),
    ]);
    expect(await request, isEmpty);
    expect(provider.matches, isEmpty);
    expect(provider.mode, 'solo');
  });

  test('listener joins the published request without recursive loading', () async {
    provider.setActiveUser('user-a');
    provider.setSoloSession('solo-a');
    fakeRepo.holdRequests = true;
    Future<void>? joined;
    provider.addListener(() {
      if (provider.isLoading) joined = provider.loadMatches();
    });
    final first = provider.loadMatches();
    expect(identical(first, joined), isTrue);
    expect(fakeRepo.requests, hasLength(1));
    fakeRepo.requests.single.complete(<MatchItem>[]);
    await first;
  });

}

class _FakeSwipeRepository extends SwipeRepository {
  _FakeSwipeRepository() : super(ApiService());

  List<MatchItem> matches = <MatchItem>[];
  bool holdRequests = false;
  final requests = <Completer<List<MatchItem>>>[];

  @override
  Future<List<MatchItem>> getMatches({
    String mode = 'all',
    String? scope,
    String? soloSessionId,
  }) {
    if (!holdRequests) return Future.value(matches);
    final completer = Completer<List<MatchItem>>();
    requests.add(completer);
    return completer.future;
  }
}

class _FakeCacheService extends CacheService {
  List<Dish> cachedMatches = <Dish>[];
  bool wasCleared = false;
  Completer<void>? writeGate;
  Completer<List<Dish>>? readGate;

  @override
  Future<void> cacheMatches(List<Dish> matches, {String? coupleId}) async {
    if (writeGate != null) await writeGate!.future;
    cachedMatches = matches;
  }

  @override
  Future<List<Dish>> getCachedMatches({String? coupleId}) =>
      readGate?.future ?? Future.value(<Dish>[]);

  @override
  Future<void> clearCachedMatches() async {
    wasCleared = true;
  }
}
