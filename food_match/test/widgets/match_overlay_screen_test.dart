import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/assets/app_empty_state_assets.dart';
import 'package:food_match/core/widgets/food_match_empty_state_image.dart';
import 'package:food_match/features/matches/presentation/screens/match_overlay_screen.dart';

import '../helpers/dish_test_data.dart';
import '../helpers/pump_food_match_test_app.dart';

void main() {
  testWidgets('custom match without an image uses the custom placeholder', (
    WidgetTester tester,
  ) async {
    await pumpFoodMatchTestApp(
      tester,
      MatchOverlayScreen(
        dish: buildTestDish(imageUrl: '', isCustom: true),
      ),
    );

    final FoodMatchEmptyStateImage placeholder = tester.widget(
      find.byType(FoodMatchEmptyStateImage),
    );
    expect(
      placeholder.assetPath,
      AppEmptyStateAssets.customDishPlaceholder,
    );
  });

  testWidgets('custom match with an invalid image uses the custom placeholder', (
    WidgetTester tester,
  ) async {
    await pumpFoodMatchTestApp(
      tester,
      MatchOverlayScreen(
        dish: buildTestDish(imageUrl: 'http:not-a-valid-url', isCustom: true),
      ),
    );

    final FoodMatchEmptyStateImage placeholder = tester.widget(
      find.byType(FoodMatchEmptyStateImage),
    );
    expect(
      placeholder.assetPath,
      AppEmptyStateAssets.customDishPlaceholder,
    );
  });
}
