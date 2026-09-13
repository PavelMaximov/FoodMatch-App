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

  test('opening Matches does not clear total-count badge', () {
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

    expect(controller.badgeCount, 1);
    expect(controller.bumpToken, 0);
  });

  test('scope-unresolved swipe refresh establishes count and animates', () {
    final MatchBadgeController controller = MatchBadgeController();

    controller.applyFetchedMatches(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      matchIds: <String>['match-1'],
      reason: 'swipe_match_created_scope_unresolved',
    );

    expect(controller.badgeCount, 1);
    expect(controller.authoritativeMatchIds, <String>{'match-1'});
    expect(controller.bumpToken, 1);
  });

  test('authoritative refresh corrects total count without replaying old ids', () {
    final MatchBadgeController controller = MatchBadgeController()
      ..initializeBaseline(
        userId: 'user-a',
        mode: 'solo',
        sessionId: 'solo-a',
        matchIds: <String>['match-1', 'match-2'],
      );

    controller.applyFetchedMatches(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      matchIds: <String>['match-2'],
      reason: 'shell_poll',
    );

    expect(controller.badgeCount, 1);
    expect(controller.bumpToken, 0);
  });

  test('swipe badge result applies authoritative count and one bump', () {
    final MatchBadgeController controller = MatchBadgeController();

    controller.applySwipeBadgeResult(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      badgeCount: 2,
      badgeDelta: 1,
      matchId: 'match-2',
      reason: 'test',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 1);
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

  test('zero badge delta updates count without animation', () {
    final MatchBadgeController controller = MatchBadgeController();

    controller.applySwipeBadgeResult(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      badgeCount: 3,
      badgeDelta: 0,
      matchId: 'match-3',
      reason: 'test',
    );

    expect(controller.badgeCount, 3);
    expect(controller.bumpToken, 0);
  });

  test('undo delta removes match and decrements without animation', () {
    final MatchBadgeController controller = MatchBadgeController()
      ..applySwipeBadgeResult(
        userId: 'user-a',
        mode: 'solo',
        sessionId: 'solo-a',
        badgeCount: 2,
        badgeDelta: 1,
        matchId: 'match-2',
        reason: 'test',
      );
    final int bumpToken = controller.bumpToken;

    controller.applyUndoBadgeResult(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      badgeCount: 1,
      badgeDelta: -1,
      removedMatchId: 'match-2',
      reason: 'test',
    );

    expect(controller.badgeCount, 1);
    expect(controller.knownMatchIds, isNot(contains('match-2')));
    expect(controller.bumpToken, bumpToken);
  });

  test('undo dislike updates authoritative count without animation', () {
    final MatchBadgeController controller = MatchBadgeController();

    controller.applyUndoBadgeResult(
      userId: 'user-a',
      mode: 'solo',
      sessionId: 'solo-a',
      badgeCount: 2,
      badgeDelta: 0,
      reason: 'test',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 0);
  });
}
