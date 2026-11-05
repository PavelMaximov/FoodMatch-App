import 'package:flutter/foundation.dart';

import '../../data/repositories/swipe_repository.dart';

enum AppFlowMode { solo, paired }

enum StartupRoute { modeSelection, sessionResumeChoice, pairConnection }

class StartupRouteDecision {
  const StartupRouteDecision({
    required this.route,
    this.previousMode,
    this.sessionId,
    this.notice,
  });

  final StartupRoute route;
  final AppFlowMode? previousMode;
  final String? sessionId;
  final String? notice;

  bool get isReturningUser => route == StartupRoute.sessionResumeChoice;
}

class AppFlowCoordinator {
  const AppFlowCoordinator();

  static const Duration resumeRouteResetThreshold = Duration(minutes: 15);

  void resetForAuthBoundary() {
    debugPrint('[AppFlow] authBoundary -> reset transient flow state');
  }

  bool shouldResolveStartupOnResume(DateTime? lastPausedAt, DateTime resumedAt) {
    if (lastPausedAt == null) {
      debugPrint('[AppFlow] resume: shortResume -> keepCurrentRoute');
      return false;
    }
    final Duration inactiveDuration = resumedAt.difference(lastPausedAt);
    if (inactiveDuration < resumeRouteResetThreshold) {
      debugPrint('[AppFlow] resume: shortResume -> keepCurrentRoute');
      return false;
    }
    debugPrint('[AppFlow] resume: longResume -> resolveStartupRoute');
    return true;
  }

  void logSessionInvalid(StartupRoute route) => debugPrint(
        route == StartupRoute.sessionResumeChoice
            ? '[AppFlow] resume: sessionInvalid -> sessionResumeChoice'
            : '[AppFlow] resume: sessionInvalid -> modeSelection',
      );

  Future<StartupRouteDecision> resolveStartupRoute({
    required SwipeRepository swipeRepository,
  }) async {
    final dynamic response = await swipeRepository.getSessionResumeState();
    if (response is! Map || !response.containsKey('session')) {
      throw const FormatException('Invalid session resume state');
    }
    final dynamic session = response['session'];
    if (session == null) {
      return const StartupRouteDecision(route: StartupRoute.modeSelection);
    }
    if (session is! Map || session['id'] is! String ||
        (session['id'] as String).trim().isEmpty ||
        (session['mode'] != 'solo' && session['mode'] != 'paired') ||
        !const ['resume', 'new', 'connect_pair'].contains(session['action'])) {
      throw const FormatException('Invalid session resume state');
    }
    final mode = session['mode'] == 'paired' ? AppFlowMode.paired : AppFlowMode.solo;
    final action = session['action'];
    final route = action == 'resume'
        ? StartupRoute.sessionResumeChoice
        : action == 'connect_pair' ? StartupRoute.pairConnection : StartupRoute.modeSelection;
    debugPrint('[Startup] route=$route mode=$mode status=${session['status']} action=$action');
    return StartupRouteDecision(
      route: route,
      previousMode: mode,
      sessionId: session['id']?.toString(),
      notice: action == 'new'
          ? mode == AppFlowMode.paired
              ? 'Your previous shared session has ended. Choose a new mode.'
              : 'Your previous session has ended. Choose a new mode.'
          : null,
    );
  }

  void logModeSelection(AppFlowMode mode) => debugPrint(
        mode == AppFlowMode.solo
            ? '[AppFlow] modeSelection: solo -> previousChoice'
            : '[AppFlow] modeSelection: pair -> pairConnection',
      );

  void logPreviousChoiceContinue(AppFlowMode mode) => debugPrint(
        mode == AppFlowMode.paired
            ? '[AppFlow] previousChoice: continue -> waitingForPartner'
            : '[AppFlow] previousChoice: continue -> swipe',
      );

  void logPreviousChoiceNew() => debugPrint('[AppFlow] previousChoice: new -> preFilter');

  void logFiltersButton() => debugPrint('[AppFlow] filtersButton -> preFilter');

  void logCloseX() => debugPrint('[AppFlow] closeX -> modeSelection');

  void logInviteAccepted() => debugPrint('[AppFlow] inviteAccepted -> previousChoice');

}
