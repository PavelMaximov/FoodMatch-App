import 'package:flutter/material.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/premium/domain/premium_entry_point.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';

void main() {
  for (final entry in PremiumEntryPoint.values) {
    testWidgets('renders contextual copy for ${entry.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PremiumScreen(entryPoint: entry),
        ),
      );
      expect(find.text(entry.title), findsOneWidget);
      expect(find.text(entry.subtitle), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Subscriptions coming soon'),
        250,
      );
      expect(find.text('Subscriptions coming soon'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  }
}
