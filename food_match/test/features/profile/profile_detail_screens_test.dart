import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';
import 'package:food_match/features/profile/logic/match_history_provider.dart';
import 'package:food_match/data/models/match_history.dart';
import 'package:food_match/data/models/dish.dart';
import 'package:food_match/core/widgets/food_match_empty_state_image.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../helpers/dish_test_data.dart';

void main() {
  Widget testApp(Widget screen, {ThemeMode themeMode = ThemeMode.light}) {
    final GoRouter router = GoRouter(
      initialLocation: '/profile/detail',
      routes: <RouteBase>[
        GoRoute(path: '/profile', builder: (_, __) => const SizedBox()),
        GoRoute(path: '/profile/detail', builder: (_, __) => screen),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
    );
  }

  Widget historyApp(MatchHistoryProvider provider) => testApp(
        ChangeNotifierProvider<MatchHistoryProvider>.value(
          value: provider,
          child: const MatchHistoryContent(),
        ),
      );

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

  testWidgets('Profile details render with the dark FoodMatch theme',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(const HelpScreen(), themeMode: ThemeMode.dark),
    );

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Contact Us'), findsOneWidget);
  });

  testWidgets('Match History has an image-based empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      historyApp(
        MatchHistoryProvider.seeded(
          const MatchHistory(
            solo: <MatchHistorySession>[],
            pair: <MatchHistorySession>[],
          ),
        ),
      ),
    );

    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.text('Your matched dishes will appear here.'), findsOneWidget);
    final FoodMatchEmptyStateImage image = tester.widget<FoodMatchEmptyStateImage>(
      find.byType(FoodMatchEmptyStateImage).first,
    );
    expect(
      image.assetPath,
      'assets/empty_states/empty_match_history.png',
    );
  });

  testWidgets('Match History renders Solo and Pair session sections',
      (WidgetTester tester) async {
    final now = DateTime(2026, 8, 30, 12);
    MatchHistorySession session(MatchHistoryMode mode, String id) =>
        MatchHistorySession(
          sessionId: id,
          mode: mode,
          startedAt: now,
          completedAt: now,
          partnerName: mode == MatchHistoryMode.pair ? 'Sam' : null,
          dishCount: 1,
          previewDishes: <Dish>[buildTestDish(name: 'Pasta')],
          dishes: <Dish>[buildTestDish(name: 'Pasta')],
        );
    final provider = MatchHistoryProvider.seeded(
      MatchHistory(
        solo: <MatchHistorySession>[session(MatchHistoryMode.solo, 'solo-1')],
        pair: <MatchHistorySession>[session(MatchHistoryMode.pair, 'pair-1')],
      ),
    );

    await tester.pumpWidget(historyApp(provider));

    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('Pair'), findsOneWidget);
    expect(find.text('Solo session'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
  });
}
