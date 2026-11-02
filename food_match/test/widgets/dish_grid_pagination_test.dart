import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shared/widgets/dish_grid.dart';

void main() {
  testWidgets('pagination footer remains in the same scroll view', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DishGrid(
      controller: controller,
      dishes: const [],
      savedDishIds: const {},
      onFavoriteTap: (_) async {},
      onDishTap: (_) {},
      footer: const CircularProgressIndicator(),
    ))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(controller.hasClients, isTrue);
  });
}
