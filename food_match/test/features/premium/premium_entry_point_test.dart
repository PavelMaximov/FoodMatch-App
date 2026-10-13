import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/features/premium/domain/premium_entry_point.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import '../../helpers/premium_test_fonts.dart';

void main() {
  setUpAll(loadPremiumTestFonts);
  for (final entry in PremiumEntryPoint.values) {
    testWidgets('supports ${entry.name} without advertising advanced filters', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PremiumScreen(entryPoint: entry),
        ),
      );
      expect(find.text('Unlock Premium'), findsOneWidget);
      expect(
        tester.widget<PremiumScreen>(find.byType(PremiumScreen)).entryPoint,
        entry,
      );
      expect(find.text('Advanced filters'), findsNothing);
    });
  }
}
