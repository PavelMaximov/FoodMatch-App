import 'package:flutter/foundation.dart';

import '../../data/repositories/swipe_repository.dart';
import '../../features/couple/logic/couple_provider.dart';
import '../../features/swipes/logic/swipe_provider.dart';

enum AppFlowMode { solo, paired }

enum StartupRoute { modeSelection, newOld }

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

  bool get isReturningUser => route == StartupRoute.newOld;
}

class AppFlowCoordinator {
  const AppFlowCoordinator();

  static const Duration resumeRouteResetThreshold = Duration(minutes: 15);

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
        route == StartupRoute.newOld
            ? '[AppFlow] resume: sessionInvalid -> newOld'
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

    final bool hasPairHistory = coupleProvider.hasCouple || coupleProvider.currentCouple != null;
    final AppFlowMode? previousMode = hasPairedPreset || hasPairHistory
        ? AppFlowMode.paired
        : hasSoloPreset || hasSoloSessionHistory
            ? AppFlowMode.solo
            : null;
    final bool returning = hasSoloPreset || hasPairedPreset || hasPairHistory || hasSoloSessionHistory;

    debugPrint(
      returning
          ? '[AppFlow] startup: returningUser -> newOld'
          : '[AppFlow] startup: newUser -> modeSelection',
    );

    return StartupRouteDecision(
      route: returning ? StartupRoute.newOld : StartupRoute.modeSelection,
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
    return data['preset'] is Map || data['deckEnded'] == true || data['hasHistory'] == true;
  }
}
