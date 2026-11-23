import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/shared/widgets/dish_grid.dart';
import '../helpers/premium_test_fonts.dart';

void main() {
  setUpAll(loadPremiumTestFonts);
  for (final width in [320.0, 375.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('iOS German cards fit width=$width text=$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
            locale: const Locale('de'),
            supportedLocales: const [Locale('en'), Locale('de')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: DishGrid(
                dishes: [
                  Dish.fromJson({
                    'id': 'layout',
                    'name': 'Kartoffelauflauf mit frischem Gemüse',
                    'total_time_minutes': 150,
                    'effort': 'medium',
                  }),
                ],
                savedDishIds: const {},
                onDishTap: (_) {},
                onFavoriteTap: (_) async {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
