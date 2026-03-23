import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/dish_repository.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/features/swipes/logic/swipe_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'swipe_provider_test.mocks.dart';

@GenerateMocks(<Type>[DishRepository, SwipeRepository])
void main() {
  late SwipeProvider provider;
  late MockDishRepository mockDishRepo;
  late MockSwipeRepository mockSwipeRepo;

  const testDishes = <Dish>[
    Dish(
      id: '1',
      title: 'Борщ',
      description: 'Суп',
      imageUrl: 'url1',
      cuisine: 'Russian',
      tags: <String>[],
      source: 'user',
      externalId: null,
      createdBy: 'u1',
      recipe: null,
    ),
    Dish(
      id: '2',
      title: 'Паста',
      description: 'Итальянская',
      imageUrl: 'url2',
      cuisine: 'Italian',
      tags: <String>[],
      source: 'user',
      externalId: null,
      createdBy: 'u1',
      recipe: null,
    ),
  ];

  setUp(() {
    mockDishRepo = MockDishRepository();
    mockSwipeRepo = MockSwipeRepository();
    provider = SwipeProvider(
      dishRepository: mockDishRepo,
      swipeRepository: mockSwipeRepo,
    );
  });

  test('loadDeck загружает блюда', () async {
    when(mockDishRepo.getDishes(cuisine: anyNamed('cuisine')))
        .thenAnswer((_) async => testDishes);

    await provider.loadDeck();

    expect(provider.deck.length, 2);
    expect(provider.currentDish?.title, 'Борщ');
    expect(provider.isDeckEmpty, false);
  });

  test('like сдвигает currentIndex', () async {
    when(mockDishRepo.getDishes(cuisine: anyNamed('cuisine')))
        .thenAnswer((_) async => testDishes);
    when(
      mockSwipeRepo.sendSwipe(
        dishId: anyNamed('dishId'),
        action: anyNamed('action'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    await provider.loadDeck();
    await provider.like();

    expect(provider.currentDish?.title, 'Паста');
  });

  test('дека становится пустой после всех свайпов', () async {
    when(mockDishRepo.getDishes(cuisine: anyNamed('cuisine')))
        .thenAnswer((_) async => testDishes);
    when(
      mockSwipeRepo.sendSwipe(
        dishId: anyNamed('dishId'),
        action: anyNamed('action'),
      ),
    ).thenAnswer((_) async => <String, dynamic>{});

    await provider.loadDeck();
    await provider.like();
    await provider.dislike();

    expect(provider.isDeckEmpty, true);
    expect(provider.currentDish, isNull);
  });
}
