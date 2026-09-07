import '../../features/matches/logic/match_provider.dart';
import '../../features/swipes/logic/swipe_provider.dart';
import 'nav_badge_animation_controller.dart';

/// Applies a swipe-created Solo match to the app-level badge state.
///
/// Returning false means the event was already handled. The caller may safely
/// refresh matches after a true result; the optimistic entry keeps the badge
/// visible until the session-scoped API response catches up.
bool registerSoloMatchBadgeEvent({
  required SoloMatchCreatedEvent event,
  required MatchProvider matchProvider,
  required NavBadgeAnimationController animationController,
}) {
  if (!matchProvider.isSoloMode ||
      matchProvider.activeSoloSessionId != event.sessionId) {
    matchProvider.setSoloSession(event.sessionId);
  }
  final bool accepted = matchProvider.recordSoloMatchFromSwipe(
    dish: event.dish,
    sessionId: event.sessionId,
    eventId: event.eventId,
  );
  if (!accepted) return false;
  animationController.showSoloMatchesPlusOne(eventKey: event.key);
  return true;
}
