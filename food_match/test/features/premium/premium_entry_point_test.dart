import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/premium/domain/premium_entry_point.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';

void main() {
  for (final entry in PremiumEntryPoint.values) {
    testWidgets('supports contextual route ${entry.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: PremiumScreen(entryPoint: entry)),
      );
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(
        tester.widget<PremiumScreen>(find.byType(PremiumScreen)).entryPoint,
        entry,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == entry.subtitle,
        ),
        findsOneWidget,
      );
    });
  }
}
