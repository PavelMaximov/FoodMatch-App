import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:food_match/shell/logic/match_badge_controller.dart';
import 'package:food_match/shell/presentation/widgets/matches_nav_badge.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'renders first Solo match badge and active plus-one animation',
    (WidgetTester tester) async {
      final MatchBadgeController badgeController =
          MatchBadgeController()
            ..setActiveUser('user-a')
            ..setScope(mode: 'solo', sessionId: 'solo-b');

      await tester.pumpWidget(
        _badgeHarness(badgeController: badgeController),
      );
      expect(find.byKey(const Key('matches-nav-count-badge')), findsNothing);

      badgeController.registerNewMatch(
        matchId: 'match-1',
        source: 'test',
        mode: 'solo',
        sessionId: 'solo-b',
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('matches-nav-count-badge')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      final Opacity plusOne = tester.widget<Opacity>(
        find.byKey(const Key('matches-nav-plus-one')),
      );
      expect(plusOne.opacity, greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('user synchronization during build defers notification', (
    WidgetTester tester,
  ) async {
    final MatchBadgeController controller = MatchBadgeController()
      ..initializeBaseline(
        userId: 'user-a',
        mode: 'solo',
        sessionId: 'solo-a',
        matchIds: <String>['match-1'],
      );

    await tester.pumpWidget(
      ChangeNotifierProvider<MatchBadgeController>.value(
        value: controller,
        child: MaterialApp(
          home: Consumer<MatchBadgeController>(
            builder: (_, MatchBadgeController badge, __) {
              badge.setActiveUser('user-b', reason: 'provider_update');
              return Text('${badge.badgeCount}');
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(controller.activeUserId, 'user-b');
    expect(controller.badgeCount, 0);
  });
}

Widget _badgeHarness({
  required MatchBadgeController badgeController,
}) {
  return ChangeNotifierProvider<MatchBadgeController>.value(
    value: badgeController,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: SizedBox(
            width: 40,
            height: 32,
            child: _BadgeHost(),
          ),
        ),
      ),
    ),
  );
}

class _BadgeHost extends StatefulWidget {
  const _BadgeHost();

  @override
  State<_BadgeHost> createState() => _BadgeHostState();
}

class _BadgeHostState extends State<_BadgeHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  MatchBadgeController? _badgeController;
  int _previousBumpToken = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final MatchBadgeController next =
        context.read<MatchBadgeController>();
    if (identical(next, _badgeController)) return;
    _badgeController?.removeListener(_handleBadgeChanged);
    _badgeController = next..addListener(_handleBadgeChanged);
    _previousBumpToken = next.bumpToken;
  }

  void _handleBadgeChanged() {
    final int token = _badgeController?.bumpToken ?? 0;
    if (token == _previousBumpToken) return;
    _previousBumpToken = token;
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _badgeController?.removeListener(_handleBadgeChanged);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MatchBadgeController badge =
        context.watch<MatchBadgeController>();
    return MatchesNavBadge(
      count: badge.badgeCount,
      mode: badge.mode,
      sessionId: badge.sessionId,
      animation: _animation,
      animationEventKey: badge.lastAnimationEventId,
      bumpToken: badge.bumpToken,
    );
  }
}
