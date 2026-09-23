import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shared/widgets/empty_state.dart';

import '../helpers/pump_food_match_test_app.dart';

void main() {
  testWidgets('EmptyState показывает title и subtitle', (tester) async {
    await pumpFoodMatchTestApp(
      tester,
      const Scaffold(
        body: EmptyState(
          icon: Icons.favorite,
          title: 'Пусто',
          subtitle: 'Ничего нет',
        ),
      ),
    );

    expect(find.text('Пусто'), findsOneWidget);
    expect(find.text('Ничего нет'), findsOneWidget);
  });

  testWidgets('EmptyState показывает кнопку если задана', (tester) async {
    await pumpFoodMatchTestApp(
      tester,
      Scaffold(
        body: EmptyState(
          icon: Icons.favorite,
          title: 'Пусто',
          subtitle: 'Ничего нет',
          buttonText: 'Обновить',
          onButtonPressed: () {},
        ),
      ),
    );

    expect(find.text('Обновить'), findsOneWidget);
  });
}
