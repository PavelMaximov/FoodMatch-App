import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/features/swipes/presentation/widgets/swipe_card_widget.dart';

void main() {
  const dish = Dish(
    id: '1',
    title: 'Тестовое блюдо',
    description: 'Описание',
    imageUrl: 'https://via.placeholder.com/300',
    cuisine: 'Russian',
    tags: <String>['суп', 'горячее'],
    source: 'user',
    externalId: null,
    createdBy: 'u1',
    recipe: null,
  );

  testWidgets('SwipeCardWidget показывает название и cuisine', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SwipeCardWidget(dish: dish)),
      ),
    );

    expect(find.text('Тестовое блюдо'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
  });
}
