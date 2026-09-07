import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';

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
