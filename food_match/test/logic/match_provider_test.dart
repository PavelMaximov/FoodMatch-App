import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/features/matches/logic/match_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'match_provider_test.mocks.dart';

@GenerateMocks(<Type>[SwipeRepository])
void main() {
  late MatchProvider provider;
  late MockSwipeRepository mockRepo;

  const dishes = <Dish>[
    Dish(
      id: '1',
      title: 'Борщ',
      description: 'Суп',
      imageUrl: 'url1',
      cuisine: 'Russian',
      tags: <String>['hot'],
      source: 'user',
      externalId: null,
      createdBy: 'u1',
      recipe: null,
    ),
  ];

  setUp(() {
    mockRepo = MockSwipeRepository();
    provider = MatchProvider(swipeRepository: mockRepo);
  });

  test('loadMatches загружает список матчей', () async {
    when(mockRepo.getMatches()).thenAnswer((_) async => dishes);

    await provider.loadMatches();

    expect(provider.matchCount, 1);
    expect(provider.matches.first.title, 'Борщ');
  });

  test('clearMatches очищает матчи', () async {
    provider.matches = dishes.toList();

    provider.clearMatches();

    expect(provider.matches, isEmpty);
  });
}
