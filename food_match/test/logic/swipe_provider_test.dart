import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';
import 'package:food_match/shell/logic/match_badge_controller.dart';

import '../helpers/dish_test_data.dart';

void main() {
  late SwipeProvider provider;
  late _FakeDishRepository fakeDishRepo;
  late _FakeSwipeRepository fakeSwipeRepo;
  late _FakeCacheService fakeCacheService;
  late MatchBadgeController badgeController;

  final List<Dish> testDishes = <Dish>[
    buildTestDish(id: '1', name: 'Borscht', description: 'Soup', cuisine: 'Russian'),
    buildTestDish(id: '2', name: 'Pasta', description: 'Italian', cuisine: 'Italian'),
  ];

  setUp(() {
    fakeDishRepo = _FakeDishRepository()..dishes = testDishes;
    fakeSwipeRepo = _FakeSwipeRepository();
    fakeCacheService = _FakeCacheService();
    badgeController = MatchBadgeController();

    provider = SwipeProvider(
      dishRepository: fakeDishRepo,
      swipeRepository: fakeSwipeRepo,
      coupleRepository: _FakeCoupleRepository(),
      cacheService: fakeCacheService,
      userProfileService: _FakeUserProfileHiveService(),
      badgeController: badgeController,
    );
    provider.currentSwipeMode = 'solo';
  });

  test('loadDeck loads dishes', () async {
    await provider.loadDeck();

    expect(provider.deck.length, 2);
    expect(provider.currentDish?.name, 'Borscht');
    expect(provider.isDeckEmpty, false);
    expect(fakeCacheService.cachedDishes, testDishes);
  });

  test('like advances currentIndex', () async {
    await provider.loadDeck();
    await provider.like();

    expect(provider.currentDish?.name, 'Pasta');
    expect(fakeSwipeRepo.sentSwipes.single, ('1', 'like'));
  });

  test('deck becomes empty after all swipes', () async {
    await provider.loadDeck();
    await provider.like();
    await provider.dislike();

    expect(provider.isDeckEmpty, true);
    expect(provider.currentDish, isNull);
    expect(fakeSwipeRepo.sentSwipes, <(String, String)>[('1', 'like'), ('2', 'dislike')]);
  });

  test('matchCreated updates app badge before a matches refresh', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'id': 'swipe-1',
        'direction': 'like',
        'matchId': 'match-1',
        'matchCreated': true,
        'badgeCount': 1,
        'badgeDelta': 1,
      },
    };

    await provider.like();

    expect(badgeController.badgeCount, 1);
    expect(badgeController.bumpToken, 1);
    expect(badgeController.sessionId, 'solo-new');
  });

  test('dislike never updates badge even when response claims a match', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'id': 'swipe-1',
        'direction': 'dislike',
        'matchId': 'match-1',
        'matchCreated': true,
      },
    };

    await provider.dislike();

    expect(badgeController.badgeCount, 0);
    expect(badgeController.bumpToken, 0);
  });

  test('swipe and dish ids are not accepted as match ids', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'id': 'swipe-1',
        'direction': 'like',
        'dishId': 'dish-1',
        'matchCreated': true,
      },
    };

    await provider.like();

    expect(badgeController.badgeCount, 0);
    expect(badgeController.bumpToken, 0);
  });

  test('created solo session requests authoritative match refresh', () async {
    String? refreshReason;
    badgeController.attachRefreshHandler(({
      required String mode,
      required String? sessionId,
      required String reason,
      String? removedMatchId,
    }) async {
      refreshReason = reason;
    });
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'direction': 'like',
        'matchId': 'match-1',
        'matchCreated': true,
      },
    };

    await provider.like();
    await Future<void>.delayed(Duration.zero);

    expect(badgeController.badgeCount, 0);
    expect(refreshReason, 'swipe_match_created');
  });

  test('like without a created match does not update badge', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'direction': 'like',
        'matchCreated': false,
        'badgeCount': 3,
        'badgeDelta': 0,
      },
    };

    await provider.like();

    expect(badgeController.badgeCount, 3);
    expect(badgeController.bumpToken, 0);
  });

  test('undo shows the previous card while pending and rolls back on failure', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[], moods: <String>[], blocked: <String>[], diet: <String>[],
    );
    await provider.like();
    expect(provider.currentDish?.id, '2');
    fakeSwipeRepo.pendingUndo = Completer<dynamic>();
    final pending = provider.undo();
    expect(provider.currentDish?.id, '1');
    expect(provider.isSendingSwipe, isTrue);
    expect(provider.canUndo, isFalse);
    fakeSwipeRepo.pendingUndo!.completeError(Exception('offline'));
    await pending;
    expect(provider.currentDish?.id, '2');
    expect(provider.isSendingSwipe, isFalse);
    expect(provider.canUndo, isTrue);
  });

  test('compact undo keeps the deck and allows another swipe', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[], moods: <String>[], blocked: <String>[], diet: <String>[],
    );
    await provider.like();
    final originalDeck = provider.deck;
    fakeSwipeRepo.undoResult = <String, dynamic>{
      'undo': <String, dynamic>{'success': true},
      'session': <String, dynamic>{
        'sessionId': 'solo-new', 'status': 'active',
        'deckUnchanged': true, 'restoredDishId': '1', 'matchedCount': 0,
      },
    };
    await provider.undo();
    expect(identical(provider.deck, originalDeck), isTrue);
    expect(provider.currentDish?.id, '1');
    expect(provider.isSendingSwipe, isFalse);
    expect(provider.canUndo, isFalse);
    await provider.dislike();
    expect(provider.currentDish?.id, '2');
    expect(provider.error, isNull);
  });

  test('undo match decrements badge without a new animation bump', () async {
    provider.setActiveUser('user-a');
    fakeSwipeRepo.soloSessionDishes = testDishes;
    await provider.createSoloSession(
      dishRegisters: <String>['everyday'],
      includeCustomDishesFirst: false,
      cuisines: <String>[],
      moods: <String>[],
      blocked: <String>[],
      diet: <String>[],
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'direction': 'like',
        'matchId': 'match-1',
        'matchCreated': true,
        'badgeCount': 2,
        'badgeDelta': 1,
      },
    };
    await provider.like();
    final int bumpToken = badgeController.bumpToken;
    fakeSwipeRepo.undoResult = <String, dynamic>{
      'undo': <String, dynamic>{
        'badgeCount': 1,
        'badgeDelta': -1,
        'matchRemoved': true,
        'removedMatchId': 'match-1',
      },
      'session': <String, dynamic>{
        'sessionId': 'solo-new',
        'status': 'active',
        'matchedCount': 1,
        'dishes': testDishes.map((Dish dish) => dish.toJson()).toList(),
        'meta': <String, dynamic>{},
      },
    };

    await provider.undo();

    expect(badgeController.badgeCount, 1);
    expect(badgeController.bumpToken, bumpToken);
  });

  test('next card is available before the first response; writes stay ordered', () async {
    await provider.loadDeck();
    fakeSwipeRepo.holdSwipes = true;
    final first = provider.like();
    expect(provider.currentIndex, 1);
    expect(provider.canAcceptSwipe, isTrue);
    expect(provider.canUndo, isFalse);
    final second = provider.dislike();
    expect(provider.currentIndex, 2);
    await Future<void>.delayed(Duration.zero);
    expect(fakeSwipeRepo.sentSwipes, <(String, String)>[('1', 'like')]);
    fakeSwipeRepo.requests.first.complete(<String, dynamic>{});
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(fakeSwipeRepo.sentSwipes, <(String, String)>[('1', 'like'), ('2', 'dislike')]);
    fakeSwipeRepo.requests.last.complete(<String, dynamic>{});
    await second;
    expect(provider.isSendingSwipe, isFalse);
    expect(provider.canUndo, isTrue);
  });

  test('failed write restores its card and cancels queued writes', () async {
    await provider.loadDeck();
    fakeSwipeRepo.holdSwipes = true;
    final first = provider.like();
    final second = provider.dislike();
    await Future<void>.delayed(Duration.zero);
    fakeSwipeRepo.requests.first.completeError(const ApiException('Rejected', statusCode: 400));
    await Future.wait([first, second]);
    expect(provider.currentIndex, 0);
    expect(provider.isSendingSwipe, isFalse);
    expect(provider.error, isNotNull);
    expect(fakeSwipeRepo.sentSwipes, hasLength(1));
    final retry = provider.like();
    await Future<void>.delayed(Duration.zero);
    fakeSwipeRepo.requests.last.complete(<String, dynamic>{});
    await retry;
    expect(provider.currentIndex, 1);
  });

  test('deck reset drops queued writes and ignores the old response', () async {
    await provider.loadDeck();
    fakeSwipeRepo.holdSwipes = true;
    final first = provider.like();
    final second = provider.dislike();
    await Future<void>.delayed(Duration.zero);
    provider.clearForLogout();
    fakeSwipeRepo.requests.first.complete(<String, dynamic>{});
    await Future.wait([first, second]);
    expect(provider.deck, isEmpty);
    expect(provider.currentIndex, 0);
    expect(provider.canUndo, isFalse);
    expect(fakeSwipeRepo.sentSwipes, hasLength(1));
  });

}

class _FakeDishRepository extends DishRepository {
  _FakeDishRepository() : super(ApiService());

  List<Dish> dishes = <Dish>[];

  @override
  Future<List<Dish>> getDishes({String? cuisine}) async => dishes;
}

class _FakeCoupleRepository extends CoupleRepository {
  _FakeCoupleRepository() : super(ApiService());
}

class _FakeSwipeRepository extends SwipeRepository {
  _FakeSwipeRepository() : super(ApiService());

  final List<(String, String)> sentSwipes = <(String, String)>[];
  List<Dish> soloSessionDishes = <Dish>[];
  dynamic swipeResult = <String, dynamic>{};
  Completer<dynamic>? pendingUndo;
  bool holdSwipes = false;
  final requests = <Completer<dynamic>>[];
  dynamic undoResult = <String, dynamic>{};

  @override
  Future<dynamic> createSoloSession({
    required Map<String, dynamic> filter,
    bool startOver = false,
  }) async => <String, dynamic>{
    'session': <String, dynamic>{
      'sessionId': 'solo-new',
      'status': 'active',
      'matchedCount': 0,
      'dishes': soloSessionDishes.map((Dish dish) => dish.toJson()).toList(),
      'meta': <String, dynamic>{},
    },
  };

  @override
  Future<dynamic> sendSwipe({
    required String dishId,
    required String direction,
    String? soloSessionId,
  }) async {
    sentSwipes.add((dishId, direction));
    if (holdSwipes) {
      final completer = Completer<dynamic>();
      requests.add(completer);
      return completer.future;
    }
    return swipeResult;
  }

  @override
  Future<dynamic> undoSoloSwipe(String sessionId) async =>
      pendingUndo == null ? undoResult : await pendingUndo!.future;
}

class _FakeCacheService extends CacheService {
  List<Dish> cachedDishes = <Dish>[];

  @override
  Future<void> cacheDishes(List<Dish> dishes) async {
    cachedDishes = dishes;
  }

  @override
  Future<List<Dish>> getCachedDishes() async => <Dish>[];
}

class _FakeUserProfileHiveService extends UserProfileHiveService {
  @override
  Future<void> recordSwipe({
    required String userId,
    required String dishId,
    required String direction,
    required String cuisine,
  }) async {}

  @override
  Future<void> recordMatch({
    required String userId,
    required String dishId,
  }) async {}
}
