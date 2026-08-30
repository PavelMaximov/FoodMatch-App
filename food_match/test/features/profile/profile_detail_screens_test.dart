import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget testApp(Widget screen) {
    final GoRouter router = GoRouter(
      initialLocation: '/profile/detail',
      routes: <RouteBase>[
        GoRoute(path: '/profile', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/profile/detail', builder: (_, __) => screen),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('About FoodMatch groups product and legal information',
      (WidgetTester tester) async {
    await tester.pumpWidget(testApp(const AboutFoodMatchScreen()));

    expect(find.text('About FoodMatch'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
  });

  testWidgets('Help groups support and sharing actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(testApp(const HelpScreen()));

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
    expect(find.text('Rate Us'), findsOneWidget);
    expect(find.text('Share App'), findsOneWidget);
  });
}
