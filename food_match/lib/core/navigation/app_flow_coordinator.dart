import 'package:flutter/foundation.dart';

import '../../data/repositories/swipe_repository.dart';
import '../../features/couple/logic/couple_provider.dart';
import '../../features/swipes/logic/swipe_provider.dart';

enum AppFlowMode { solo, paired }

enum StartupRoute { modeSelection, sessionResumeChoice }

class StartupRouteDecision {
  const StartupRouteDecision({
    required this.route,
    this.previousMode,
    this.hasSoloPreset = false,
    this.hasPairedPreset = false,
    this.hasPairHistory = false,
    this.hasSoloSessionHistory = false,
  });

  final StartupRoute route;
  final AppFlowMode? previousMode;
  final bool hasSoloPreset;
  final bool hasPairedPreset;
  final bool hasPairHistory;
  final bool hasSoloSessionHistory;

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
    required SwipeProvider swipeProvider,
    required CoupleProvider coupleProvider,
  }) async {
    bool hasSoloPreset = false;
    bool hasPairedPreset = false;
    bool hasSoloSessionHistory = false;
    bool hasPairPreparedDeck = false;

    try {
      final dynamic solo = await swipeRepository.getLastFilterPreset('solo');
      hasSoloPreset = _hasPreset(solo);
    } catch (e) {
      debugPrint('[AppFlow] startup: solo preset check failed $e');
    }

    try {
      final dynamic paired = await swipeRepository.getLastFilterPreset('paired');
      hasPairedPreset = _hasPreset(paired);
    } catch (e) {
      debugPrint('[AppFlow] startup: paired preset check failed $e');
    }

    try {
      hasSoloSessionHistory = await swipeProvider.loadActiveSoloSession();
    } catch (e) {
      debugPrint('[AppFlow] startup: solo session check failed $e');
    }

    if (coupleProvider.hasCouple) {
      try {
        hasPairPreparedDeck = await swipeProvider.loadExistingPreparedDeck();
      } catch (e) {
        debugPrint('[Startup] pair prepared deck check failed error=$e');
      }
    }

    final bool hasPairHistory = hasPairPreparedDeck ||
        hasPairedPreset ||
        coupleProvider.needsPairResync ||
        coupleProvider.hasPendingContinuation;
    final AppFlowMode? previousMode = hasPairHistory
        ? AppFlowMode.paired
        : hasSoloPreset || hasSoloSessionHistory
            ? AppFlowMode.solo
            : null;
    final bool returning = hasSoloPreset || hasPairedPreset || hasPairHistory || hasSoloSessionHistory;

    debugPrint('[Startup] previousSessionCheck solo=$hasSoloSessionHistory '
        'pair=$hasPairHistory previousFilters=${hasSoloPreset || hasPairedPreset}');
    final String reason = hasPairPreparedDeck
        ? 'pair_active'
        : coupleProvider.needsPairResync
            ? 'pair_resync'
            : coupleProvider.hasPendingContinuation
                ? 'pair_waiting'
                : hasPairedPreset
                    ? 'previous_filters_available'
                    : hasSoloSessionHistory
                        ? 'solo_active'
                        : hasSoloPreset
                            ? 'previous_filters_available'
                            : 'no_previous_session';
    debugPrint(returning
        ? '[Startup] outcome=session_resume_choice reason=$reason'
        : '[Startup] outcome=mode_selection reason=no_previous_session');

    return StartupRouteDecision(
      route: returning
          ? StartupRoute.sessionResumeChoice
          : StartupRoute.modeSelection,
      previousMode: previousMode,
      hasSoloPreset: hasSoloPreset,
      hasPairedPreset: hasPairedPreset,
      hasPairHistory: hasPairHistory,
      hasSoloSessionHistory: hasSoloSessionHistory,
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

  bool _hasPreset(dynamic data) {
    if (data is! Map<String, dynamic>) return false;
    final dynamic rawPreset = data['preset'];
    if (rawPreset is Map) {
      final Map<dynamic, dynamic> preset = rawPreset;
      const List<String> listKeys = <String>[
        'dishRegisters',
        'cuisines',
        'moods',
        'diet',
        'exclusions',
      ];
      if (listKeys.any(
        (String key) =>
            preset[key] is List && (preset[key] as List).isNotEmpty,
      )) {
        return true;
      }
      if (preset['includeCustomDishesFirst'] == true) return true;
    }
    return data['deckEnded'] == true || data['hasHistory'] == true;
  }
}
