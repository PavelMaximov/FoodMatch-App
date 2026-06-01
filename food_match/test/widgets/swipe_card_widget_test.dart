import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/swipes/presentation/widgets/swipe_card_widget.dart';

import '../helpers/dish_test_data.dart';

void main() {
  final dish = buildTestDish(
    id: '1',
    name: 'Test dish',
    description: 'Description',
    cuisine: 'Russian',
    tags: <String>['soup', 'hot'],
  );

  testWidgets('SwipeCardWidget shows name and cuisine', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SwipeCardWidget(dish: dish)),
      ),
    );

    expect(find.text('Test dish'), findsOneWidget);
    expect(find.text('Russian'), findsOneWidget);
  });
}
