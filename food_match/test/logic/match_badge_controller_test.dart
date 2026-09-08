import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shell/logic/match_badge_controller.dart';

void main() {
  test('initial baseline restores count without animation', () {
    final MatchBadgeController controller =
        MatchBadgeController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'solo', sessionId: 'solo-a');

    controller.applyFetchedMatches(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      matchIds: <String>['match-1', 'match-2'],
      reason: 'initial_load',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 0);
  });

  test('immediate match increments once and refresh does not replay bump', () {
    final MatchBadgeController controller =
        MatchBadgeController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'solo', sessionId: 'solo-a')
          ..applyFetchedMatches(
            userId: 'user-a',
            mode: 'solo',
            sessionId: 'solo-a',
            matchIds: <String>['match-1'],
            reason: 'initial_load',
          );

    controller.registerNewMatch(
      matchId: 'match-2',
      source: 'test',
      mode: 'solo',
      sessionId: 'solo-a',
    );
    controller.applyFetchedMatches(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      matchIds: <String>['match-1', 'match-2'],
      reason: 'swipe_match_created',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 1);
  });

  test('same-user scope survives navigation-style refreshes', () {
    final MatchBadgeController controller =
        MatchBadgeController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'paired', sessionId: 'pair-a')
          ..applyFetchedMatches(
            userId: 'user-a',
            mode: 'paired',
            sessionId: 'pair-a',
            matchIds: <String>['match-1'],
            reason: 'initial_load',
          );

    controller.setActiveUser('user-a');
    controller.setScope(mode: 'paired', sessionId: 'pair-a');

    expect(controller.badgeCount, 1);
    expect(controller.bumpToken, 0);
  });

  test('opening Matches marks badge entries seen without replaying animation', () {
    final MatchBadgeController controller = MatchBadgeController()
      ..initializeBaseline(
        userId: 'user-a',
        mode: 'solo',
        sessionId: 'solo-a',
        matchIds: <String>['match-1'],
      );

    controller.markAllSeen(reason: 'matches_tab_opened');
    controller.applyFetchedMatches(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      matchIds: <String>['match-1'],
      reason: 'matches_screen_opened',
    );

    expect(controller.badgeCount, 0);
    expect(controller.bumpToken, 0);
  });
}
