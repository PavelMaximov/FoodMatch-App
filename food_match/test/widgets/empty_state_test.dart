import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shared/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState показывает title и subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.favorite,
            title: 'Пусто',
            subtitle: 'Ничего нет',
          ),
        ),
      ),
    );

    expect(find.text('Пусто'), findsOneWidget);
    expect(find.text('Ничего нет'), findsOneWidget);
  });

  testWidgets('EmptyState показывает кнопку если задана', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.favorite,
            title: 'Пусто',
            subtitle: 'Ничего нет',
            buttonText: 'Обновить',
            onButtonPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Обновить'), findsOneWidget);
  });
}
