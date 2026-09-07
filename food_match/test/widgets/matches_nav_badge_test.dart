import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/shell/presentation/widgets/matches_nav_badge.dart';

void main() {
  testWidgets(
    'renders first Solo match badge and active plus-one animation',
    (WidgetTester tester) async {
      final AnimationController animation = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 800),
      );

      await tester.pumpWidget(_badgeHarness(animation: animation, count: 0));
      expect(find.byKey(const Key('matches-nav-count-badge')), findsNothing);

      await tester.pumpWidget(_badgeHarness(animation: animation, count: 1));
      animation.forward();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('matches-nav-count-badge')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      final Opacity plusOne = tester.widget<Opacity>(
        find.byKey(const Key('matches-nav-plus-one')),
      );
      expect(plusOne.opacity, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
      animation.dispose();
    },
  );
}

Widget _badgeHarness({
  required Animation<double> animation,
  required int count,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 40,
          height: 32,
          child: MatchesNavBadge(
            count: count,
            mode: 'solo',
            sessionId: 'solo-b',
            animation: animation,
            animationEventKey: 'solo:solo-b:swipe-1',
          ),
        ),
      ),
    ),
  );
}
