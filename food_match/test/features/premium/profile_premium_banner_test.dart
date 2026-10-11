import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/profile/presentation/widgets/profile_premium_banner.dart';

void main() {
  testWidgets('Premium Profile state renders Active', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePremiumBanner(isPremium: true, onTap: () {}),
        ),
      ),
    );

    expect(find.text('FoodMatch Premium'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });
}
