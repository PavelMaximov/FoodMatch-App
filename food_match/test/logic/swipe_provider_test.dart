import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/local/user_profile_hive_service.dart';
import 'package:food_match/data/models/dish.dart';
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
}

class _FakeDishRepository extends DishRepository {
  _FakeDishRepository() : super(ApiService());

  List<Dish> dishes = <Dish>[];

  @override
  Future<List<Dish>> getDishes({String? cuisine}) async => dishes;
}

class _FakeSwipeRepository extends SwipeRepository {
  _FakeSwipeRepository() : super(ApiService());

  final List<(String, String)> sentSwipes = <(String, String)>[];

  @override
  Future<dynamic> sendSwipe({required String dishId, required String direction}) async {
    sentSwipes.add((dishId, direction));
    return <String, dynamic>{};
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
