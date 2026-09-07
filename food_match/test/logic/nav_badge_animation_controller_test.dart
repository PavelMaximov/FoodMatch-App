import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shell/logic/nav_badge_animation_controller.dart';

void main() {
  test('initial baseline restores count without animation', () {
    final NavBadgeAnimationController controller =
        NavBadgeAnimationController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'solo', sessionId: 'solo-a');

    controller.applyFetchedMatches(
      matchIds: <String>['match-1', 'match-2'],
      reason: 'initial_load',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 0);
  });

  test('immediate match increments once and refresh does not replay bump', () {
    final NavBadgeAnimationController controller =
        NavBadgeAnimationController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'solo', sessionId: 'solo-a')
          ..applyFetchedMatches(
            matchIds: <String>['match-1'],
            reason: 'initial_load',
          );

    controller.registerImmediateMatch(
      matchId: 'match-2',
      mode: 'solo',
      sessionId: 'solo-a',
    );
    controller.applyFetchedMatches(
      matchIds: <String>['match-1', 'match-2'],
      reason: 'swipe_match_created',
    );

    expect(controller.badgeCount, 2);
    expect(controller.bumpToken, 1);
  });

  test('same-user scope survives navigation-style refreshes', () {
    final NavBadgeAnimationController controller =
        NavBadgeAnimationController()
          ..setActiveUser('user-a')
          ..setScope(mode: 'paired', sessionId: 'pair-a')
          ..applyFetchedMatches(
            matchIds: <String>['match-1'],
            reason: 'initial_load',
          );

    controller.setActiveUser('user-a');
    controller.setScope(mode: 'paired', sessionId: 'pair-a');

    expect(controller.badgeCount, 1);
    expect(controller.bumpToken, 0);
  });
}
