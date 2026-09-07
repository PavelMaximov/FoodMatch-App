import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';
import 'package:food_match/shell/logic/nav_badge_animation_controller.dart';
import 'package:food_match/shell/logic/solo_match_badge_coordinator.dart';

import '../helpers/dish_test_data.dart';

void main() {
  late SwipeProvider provider;
  late _FakeDishRepository fakeDishRepo;
  late _FakeSwipeRepository fakeSwipeRepo;
  late _FakeCacheService fakeCacheService;

  final List<Dish> testDishes = <Dish>[
    buildTestDish(id: '1', name: 'Borscht', description: 'Soup', cuisine: 'Russian'),
    buildTestDish(id: '2', name: 'Pasta', description: 'Italian', cuisine: 'Italian'),
  ];

  setUp(() {
    fakeDishRepo = _FakeDishRepository()..dishes = testDishes;
    fakeSwipeRepo = _FakeSwipeRepository();
    fakeCacheService = _FakeCacheService();

    provider = SwipeProvider(
      dishRepository: fakeDishRepo,
      swipeRepository: fakeSwipeRepo,
      coupleRepository: _FakeCoupleRepository(),
      cacheService: fakeCacheService,
      userProfileService: _FakeUserProfileHiveService(),
    );
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

  test('Solo matchCreated emits app-level event before Matches screen load', () async {
    fakeSwipeRepo.soloSessionDishes = testDishes;
    expect(
      await provider.createSoloSession(
        dishRegisters: <String>['everyday'],
        includeCustomDishesFirst: false,
        cuisines: <String>[],
        moods: <String>[],
        blocked: <String>[],
        diet: <String>[],
      ),
      isTrue,
    );
    fakeSwipeRepo.swipeResult = <String, dynamic>{
      'swipe': <String, dynamic>{
        'id': 'swipe-first',
        'dishId': '1',
        'matchCreated': true,
        'mode': 'solo',
      },
    };

    await provider.like();

    expect(provider.soloMatchCreatedEvent?.sessionId, 'solo-new');
    expect(provider.soloMatchCreatedEvent?.dish.id, '1');
    expect(provider.soloMatchCreatedEvent?.eventId, 'swipe-first');
  });

  test('app-level Solo badge chain uses the swiping provider instance', () async {
    final MatchProvider matchProvider = MatchProvider(
      swipeRepository: fakeSwipeRepo,
      cacheService: fakeCacheService,
    )..setActiveUser('user-a');
    final NavBadgeAnimationController animationController =
        NavBadgeAnimationController();
    int handledEvents = 0;
    provider.addListener(() {
      final SoloMatchCreatedEvent? event = provider.soloMatchCreatedEvent;
      if (event != null &&
          registerSoloMatchBadgeEvent(
            event: event,
            matchProvider: matchProvider,
            animationController: animationController,
          )) {
        handledEvents++;
      }
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
        'id': 'swipe-runtime',
        'dishId': '1',
        'matchCreated': true,
        'mode': 'solo',
      },
    };

    await provider.like();

    expect(matchProvider.activeSoloSessionId, provider.activeSoloSessionId);
    expect(matchProvider.matchCount, 1);
    expect(animationController.soloMatchesPlusOneEvent, 1);
    expect(handledEvents, 1);
    // Later provider notifications see the same event but cannot count it twice.
    provider.setDeckError('test notification');
    expect(matchProvider.matchCount, 1);
    expect(animationController.soloMatchesPlusOneEvent, 1);
    expect(handledEvents, 1);
  });

  test('matchCreated false does not emit a Solo badge event', () async {
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
        'id': 'swipe-no-match',
        'dishId': '1',
        'matchCreated': false,
        'mode': 'solo',
      },
    };

    await provider.like();

    expect(provider.soloMatchCreatedEvent, isNull);
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
    return swipeResult;
  }
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

class _FakeUserProfileHiveService extends UserProfileHiveService {}
