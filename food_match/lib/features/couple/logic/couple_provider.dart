import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/models/couple.dart';
import '../../../data/models/couple_filter_state.dart';
import '../../../data/models/couple_invitation.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';

class CoupleProvider extends ChangeNotifier {
  CoupleProvider({required CoupleRepository repository}) : _repository = repository;

  static const String activeSessionMessage = 'You already have an active session.';
  static const String activeSessionHasPartnerMessage = 'Please leave your current session before joining another one.';
  static const String activeSoloSessionMessage = 'Please finish or leave your solo session before joining a pair session.';
  static const String invalidInviteCodeMessage = 'Invalid session code.';
  static const String sessionFullMessage = 'This session is already full.';
  static const String sessionInactiveMessage = 'This session is no longer active.';
  static const String ownSessionMessage = 'You can’t join your own session.';
  static const String partnerLeftSessionMessage =
      'Your partner has left this session. Please start or join a new session.';

  final CoupleRepository _repository;
  Couple? currentCouple;
  CoupleFilterState? _filterState;
  Timer? _pollTimer;
  Timer? _invitationPollTimer;
  Duration? _activePollInterval;
  bool _pollingWanted = false;
  bool _isAppActive = true;
  int _pollErrorStreak = 0;
  bool _disposed = false;
  bool _pollingSuspendedForDeckPrepare = false;
  bool _joinInFlight = false;
  bool _leaveInFlight = false;
  bool _isRefreshingCurrentCouple = false;
  bool _isRefreshingFilterState = false;
  Future<CoupleFilterState?>? _filterStateRefreshFuture;
  DateTime? _currentCoupleLoadedAt;
  bool _isAuthenticated = false;
  String? _activeUserId;

  bool isLoading = false;
  String? error;
  String? sessionEndedMessage;
  int _sessionStateVersion = 0;
  List<CoupleInvitation> pendingInvitations = <CoupleInvitation>[];
  CoupleInvitation? outgoingContinuationInvite;
  final Set<String> hiddenInvitationIds = <String>{};
  bool shouldOpenPreviousChoiceAfterInvite = false;
  bool previousChoiceAfterInviteWasUserAccepted = false;
  bool shouldOpenSessionResumeForResync = false;
  bool shouldOpenPairFilterChange = false;
  String? pairNeedsResyncMessage;
  final Set<int> _handledLifecycleGenerations = <int>{};
  final Set<int> _handledFilterChangeGenerations = <int>{};
  final Set<String> _consumedAcceptedInviteIds = <String>{};
  int _authBoundaryVersion = -1;

  bool get hasCouple {
    final Couple? couple = currentCouple;
    return couple != null && couple.inviteCode.trim().isNotEmpty;
  }
  String? get inviteCode => currentCouple?.inviteCode;
  int get sessionStateVersion => _sessionStateVersion;
  CoupleFilterChoices get myChoices => _filterState?.myChoices ?? const CoupleFilterChoices();
  CoupleFilterChoices? get partnerChoices => _filterState?.partnerChoices;
  bool get bothConfirmed => _filterState?.bothConfirmed ?? false;
  int get compatibility => _filterState?.compatibility ?? 0;
  bool get isPartnerReady => _filterState?.partnerChoices?.confirmed == true;
  bool get isMyChoicesConfirmed => _filterState?.myChoices.confirmed ?? false;
  bool get hasPartner => (currentCouple?.members.length ?? 0) >= 2;
  String? get syncMessage => error;
  bool get isJoining => _joinInFlight;
  bool get isLeaving => _leaveInFlight;
  bool get hasActiveSessionConflict => error == activeSessionMessage;
  bool get needsPairResync => shouldOpenSessionResumeForResync;
  bool get needsPairFilterChange => shouldOpenPairFilterChange;

  CoupleInvitation? get nextIncomingInvitation {
    for (final CoupleInvitation invitation in pendingInvitations) {
      if (invitation.isIncoming && invitation.isPending && !hiddenInvitationIds.contains(invitation.id)) {
        return invitation;
      }
    }
    return null;
  }
  bool get _canPollFilterState => !_disposed && _isAppActive && _isAuthenticated && (_activeUserId?.isNotEmpty ?? false) && hasCouple;
  bool get _hasFreshCurrentCoupleCache {
    final DateTime? loadedAt = _currentCoupleLoadedAt;
    return loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.currentCoupleTtl;
  }

  void setAuthenticatedUser(String? userId, {required bool isAuthenticated}) {
    final String? normalized = userId?.trim().isEmpty == true ? null : userId?.trim();
    final bool nextAuthenticated = isAuthenticated && normalized != null;
    final bool userChanged = _activeUserId != normalized;
    if (!userChanged && _isAuthenticated == nextAuthenticated) {
      return;
    }

    _activeUserId = normalized;
    _isAuthenticated = nextAuthenticated;
    if (!nextAuthenticated) {
      stopInvitationPolling(reason: 'unauthenticated');
      clearSessionStateForLogout(notify: false);
      return;
    }

    if (userChanged) {
      _clearSessionState();
      pendingInvitations = <CoupleInvitation>[];
      outgoingContinuationInvite = null;
      hiddenInvitationIds.clear();
      _consumedAcceptedInviteIds.clear();
      shouldOpenPreviousChoiceAfterInvite = false;
      previousChoiceAfterInviteWasUserAccepted = false;
      shouldOpenPairFilterChange = false;
      AppLogger.info('[CoupleProvider] session state cleared for account switch');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopFilterStatePolling(reason: 'dispose');
    stopInvitationPolling(reason: 'dispose');
    super.dispose();
  }

  Future<void> loadCouple({bool force = false}) async {
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true)) {
      clearSessionStateForLogout(notify: false);
      return;
    }
    if (_isRefreshingCurrentCouple) {
      AppLogger.info('[RequestDedup] couple/me refresh skipped: already in flight');
      return;
    }
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    final bool previouslyHadSession = hasCouple;
    if (!force && _hasFreshCurrentCoupleCache) {
      final int age = DateTime.now().difference(_currentCoupleLoadedAt!).inSeconds;
      AppLogger.info('[Cache] couple/me hit hasCouple=$hasCouple age=${age}s');
      if (hasCouple) {
        await refreshFilterState();
      }
      return;
    }

    _isRefreshingCurrentCouple = true;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      AppLogger.info(force ? '[Cache] couple/me force refresh' : '[Cache] couple/me miss');
      final Couple? loadedCouple = await _repository.getMyCouple();
      if (!_isCurrentSession(requestVersion, requestUserId)) return;
      final String? previousCoupleId = currentCouple?.id;
      currentCouple = loadedCouple;
      if (previousCoupleId != null && previousCoupleId != currentCouple?.id) {
        hiddenInvitationIds.clear();
        outgoingContinuationInvite = null;
        AppLogger.info('[PairInvitation] cleared local invitation state reason=session_changed');
      }
      _currentCoupleLoadedAt = DateTime.now();
      _detectPairLifecycleResync();
      if (hasCouple) {
        await refreshFilterState();
      } else {
        _handleSessionEndedIfNeeded(previouslyHadSession: previouslyHadSession);
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _handleSessionEndedIfNeeded(previouslyHadSession: previouslyHadSession, incrementVersion: false);
      } else {
        error = _mapError(e);
      }
    } finally {
      _isRefreshingCurrentCouple = false;
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> createCouple() async {
    if (isLoading || hasCouple) return;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      currentCouple = await _repository.create();
      _currentCoupleLoadedAt = DateTime.now();
      _detectPairLifecycleResync();
      _sessionStateVersion++;
      await refreshFilterState();
    } on ApiException catch (e) {
      if (_isActiveSessionConflict(e)) {
        error = activeSessionMessage;
        await _refreshActiveSessionAfterConflict();
      } else {
        error = _mapError(e);
      }
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> joinCouple(String inviteCode, {bool replaceEmptyCurrentSession = false}) async {
    if (_joinInFlight || isLoading) return;
    if (hasCouple && !replaceEmptyCurrentSession) {
      error = activeSessionMessage;
      await refreshFilterState();
      _safeNotify();
      return;
    }

    _joinInFlight = true;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      if (replaceEmptyCurrentSession) {
        stopFilterStatePolling(reason: 'join_replace_empty_session');
      }
      currentCouple = await _repository.join(
        inviteCode,
        replaceEmptyCurrentSession: replaceEmptyCurrentSession,
      );
      _filterState = null;
      _currentCoupleLoadedAt = null;
      _sessionStateVersion++;
      await loadCouple(force: true);
      if (hasCouple) {
        startFilterStatePolling(reason: 'join_success');
      }
    } on ApiException catch (e) {
      if (_isActiveSessionConflict(e)) {
        error = activeSessionMessage;
        await _refreshActiveSessionAfterConflict();
      } else {
        error = _mapError(e);
      }
    } catch (e) {
      error = _mapError(e);
    } finally {
      _joinInFlight = false;
      isLoading = false;
      _safeNotify();
    }
  }


  Future<Map<String, dynamic>?> requestDeckRestart() async {
    try {
      error = null;
      final Map<String, dynamic> status = await _repository.requestDeckRestart();
      if (status['allRequested'] == true) {
        _filterState = const CoupleFilterState(
          myChoices: CoupleFilterChoices(),
          bothConfirmed: false,
          compatibility: 0,
          status: 'draft',
        );
        _sessionStateVersion++;
      }
      _safeNotify();
      return status;
    } catch (e) {
      error = _mapError(e);
      _safeNotify();
      return null;
    }
  }

  Future<Map<String, dynamic>?> getDeckRestartStatus() async {
    try {
      final Map<String, dynamic> status = await _repository.getDeckRestartStatus();
      if (status['allRequested'] == true) {
        _filterState = const CoupleFilterState(
          myChoices: CoupleFilterChoices(),
          bothConfirmed: false,
          compatibility: 0,
          status: 'draft',
        );
        _sessionStateVersion++;
      }
      _safeNotify();
      return status;
    } catch (e) {
      error = _mapError(e);
      _safeNotify();
      return null;
    }
  }

  Future<void> resetCouple() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.reset();
      await _repository.resetFilterState();
      await _refreshCurrentCoupleAfterReset();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> leaveCouple() async {
    if (isLoading || _leaveInFlight) return;
    _leaveInFlight = true;
    isLoading = true;
    error = null;
    _safeNotify();
    stopFilterStatePolling(reason: 'leave');
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    try {
      await _repository.leave();
      if (!_isCurrentSession(requestVersion, requestUserId)) return;
      _clearSessionState();
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _clearSessionState();
      } else {
        error = _mapError(e);
      }
    } finally {
      _leaveInFlight = false;
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> saveMyChoices({
    required List<String> cuisines,
    required List<String> moods,
    required List<String> diet,
    required List<String> exclusions,
  }) async {
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    _filterState = await _repository.updateMyFilterState(
      CoupleFilterChoices(cuisines: cuisines, moods: moods, diet: diet, exclusions: exclusions),
    );
    if (!_isCurrentSession(requestVersion, requestUserId)) return;
    _sessionStateVersion++;
    AppLogger.info('[CoupleFilterState] saved my choices');
    AppLogger.info('[Cache] prepared deck invalidated reason=filters-change');
    _safeNotify();
  }

  Future<void> saveAndConfirmMyChoices({
    required List<String> cuisines,
    required List<String> moods,
    required List<String> diet,
    required List<String> exclusions,
  }) async {
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    AppLogger.info(
      '[FilterState] saving choices cuisines=$cuisines moods=$moods diet=$diet exclusions=$exclusions',
    );
    final CoupleFilterState savedState = await _repository.updateMyFilterState(
      CoupleFilterChoices(cuisines: cuisines, moods: moods, diet: diet, exclusions: exclusions),
    );
    if (!_isCurrentSession(requestVersion, requestUserId)) return;
    _filterState = savedState;

    final CoupleFilterState confirmedState = await _repository.confirmMyFilterState();
    if (!_isCurrentSession(requestVersion, requestUserId)) return;
    _filterState = confirmedState;
    _sessionStateVersion++;
    AppLogger.info('[CoupleFilterState] saved and confirmed my choices');
    AppLogger.info('[Cache] prepared deck invalidated reason=filters-change');
    _safeNotify();
  }

  Future<void> confirmMyChoices() async {
    if (_isRefreshingFilterState) {
      AppLogger.info('[RequestDedup] confirm filter-state waits for refresh in flight');
    }
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    _filterState = await _repository.confirmMyFilterState();
    if (!_isCurrentSession(requestVersion, requestUserId)) return;
    _safeNotify();
  }

  Future<CoupleFilterState?> refreshFilterState({String reason = 'manual'}) {
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true)) {
      stopFilterStatePolling(reason: 'unauthenticated');
      return Future<CoupleFilterState?>.value(null);
    }
    if (!hasCouple) {
      stopFilterStatePolling(reason: 'no active couple');
      return Future<CoupleFilterState?>.value(null);
    }
    final Future<CoupleFilterState?>? existing = _filterStateRefreshFuture;
    if (existing != null) {
      AppLogger.info('[RequestDedup] filter-state reused existing request reason=$reason');
      return existing;
    }

    final Future<CoupleFilterState?> future = _refreshFilterStateInternal(reason: reason);
    _filterStateRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_filterStateRefreshFuture, future)) {
        _filterStateRefreshFuture = null;
      }
    });
    return future;
  }

  Future<CoupleFilterState?> _refreshFilterStateInternal({required String reason}) async {
    _isRefreshingFilterState = true;
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    final String? requestCoupleId = currentCouple?.id;
    try {
      final previousPartnerConfirmed = _filterState?.partnerChoices?.confirmed == true;
      final CoupleFilterState nextState = await _repository.getFilterState();
      if (!_isCurrentSession(requestVersion, requestUserId, coupleId: requestCoupleId)) {
        AppLogger.info('[SessionSync] stale response ignored sessionVersion=$requestVersion current=$_sessionStateVersion');
        return null;
      }
      _pollErrorStreak = 0;
      error = null;
      _filterState = nextState;
      AppLogger.info('[CoupleFilterState] loaded reason=$reason status=${nextState.status} bothConfirmed=${nextState.bothConfirmed}');
      if (nextState.myChoices.confirmed) {
        AppLogger.info('[PairFlow] filters confirmed user=self session=${currentCouple?.id ?? 'none'} generation=${currentCouple?.lifecycleGeneration ?? 0}');
      }
      if (!previousPartnerConfirmed && (nextState.partnerChoices?.confirmed == true)) {
        AppLogger.info('[CoupleFilterState] partner confirmed=true');
        AppLogger.info('[PairFlow] filters confirmed user=partner session=${currentCouple?.id ?? 'none'} generation=${currentCouple?.lifecycleGeneration ?? 0}');
      }
      if (nextState.myChoices.confirmed && !nextState.bothConfirmed) {
        AppLogger.info('[PairFlow] waiting for partner filters session=${currentCouple?.id ?? 'none'} generation=${currentCouple?.lifecycleGeneration ?? 0}');
      }
      if (nextState.bothConfirmed) {
        AppLogger.info('[PairFlow] both filters confirmed session=${currentCouple?.id ?? 'none'} generation=${currentCouple?.lifecycleGeneration ?? 0}');
      }
      _safeNotify();
      _restartPollingIfIntervalChanged();
      return nextState;
    } on ApiException catch (e) {
      _pollErrorStreak++;
      if (_isPairSessionInactive(e)) {
        AppLogger.info('[SessionSync] no active couple while refreshing; clearing session state');
        _handleSessionEndedIfNeeded(previouslyHadSession: true);
        _safeNotify();
        return null;
      }
      error = _syncErrorMessage(e);
      AppLogger.error('[SessionSync] refresh failed', e);
      _restartPollingIfNeeded(reason: 'error_backoff');
      return null;
    } catch (e) {
      _pollErrorStreak++;
      error = _syncErrorMessage(e);
      AppLogger.error('[SessionSync] refresh failed', e);
      _restartPollingIfNeeded(reason: 'error_backoff');
      return null;
    } finally {
      _isRefreshingFilterState = false;
      _filterStateRefreshFuture = null;
    }
  }

  void startFilterStatePolling({String reason = 'screen_request'}) {
    _pollingWanted = true;
    if (_pollingSuspendedForDeckPrepare) {
      AppLogger.info('[SessionSync] polling deferred reason=deck_prepare');
      return;
    }
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true)) {
      stopFilterStatePolling(reason: 'unauthenticated');
      return;
    }
    if (!hasCouple) {
      stopFilterStatePolling(reason: 'no active couple');
      return;
    }
    if (!_isAppActive) {
      AppLogger.info('[SessionSync] polling deferred reason=app_background');
      return;
    }
    final Duration interval = _pollInterval;
    if (_pollTimer != null) {
      if (_activePollInterval == interval) {
        AppLogger.info('[SessionSync] polling already active, skip');
        return;
      }
      _stopPollingTimer(reason: 'interval_change');
    }
    AppLogger.info(
      '[SessionSync] polling started interval=${interval.inSeconds}s reason=$reason',
    );
    _activePollInterval = interval;
    _pollTimer = Timer.periodic(interval, (_) {
      if (!_canPollFilterState) {
        stopFilterStatePolling(
          reason: !_isAuthenticated
              ? 'unauthenticated'
              : !_isAppActive
                  ? 'app_background'
                  : 'no active couple',
        );
        return;
      }
      if (!hasPartner) {
        loadCouple(force: true);
        return;
      }
      refreshFilterState(reason: 'poll_tick');
    });
  }

  void stopFilterStatePolling({String? reason}) {
    _pollingWanted = false;
    _pollingSuspendedForDeckPrepare = false;
    _stopPollingTimer(reason: reason);
  }

  void pauseFilterStatePollingForDeckPrepare() {
    if (_pollingSuspendedForDeckPrepare) return;
    _pollingSuspendedForDeckPrepare = true;
    _stopPollingTimer(reason: 'deck_prepare');
    AppLogger.info('[SessionSync] polling paused reason=deck_prepare');
  }

  void resumeFilterStatePollingAfterDeckPrepare({required bool succeeded}) {
    if (!_pollingSuspendedForDeckPrepare) return;
    _pollingSuspendedForDeckPrepare = false;
    if (!_pollingWanted || !_canPollFilterState) return;
    if (succeeded && bothConfirmed) {
      AppLogger.info(
        '[SessionSync] polling resumed at confirmed interval after deck_prepare',
      );
    }
    startFilterStatePolling(
      reason: succeeded ? 'deck_prepare_success' : 'deck_prepare_failed',
    );
  }

  Future<void> handleAppPaused() async {
    _isAppActive = false;
    _stopPollingTimer(reason: 'app_paused');
    stopInvitationPolling(reason: 'app_paused');
    AppLogger.info('[SessionSync] app paused: polling stopped');
  }

  Future<void> handleAppResumed() async {
    _isAppActive = true;
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true)) return;
    AppLogger.info('[SessionSync] app resumed: refreshing couple/filter-state');
    await loadCouple(force: true);
    if (_pollingWanted && hasCouple) {
      startFilterStatePolling(reason: 'app_resumed');
    }
    startInvitationPolling(reason: 'app_resumed');
    await refreshInvitations();
  }


  void startInvitationPolling({String reason = 'manual'}) {
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true) || !_isAppActive) return;
    _invitationPollTimer?.cancel();
    AppLogger.info('[InvitationSync] polling started reason=$reason');
    _invitationPollTimer = Timer.periodic(const Duration(seconds: 8), (_) => refreshInvitations());
    unawaited(refreshInvitations());
  }

  void stopInvitationPolling({String reason = 'manual'}) {
    final bool hadTimer = _invitationPollTimer != null;
    _invitationPollTimer?.cancel();
    _invitationPollTimer = null;
    if (hadTimer) AppLogger.info('[InvitationSync] polling stopped reason=$reason');
  }

  Future<void> refreshInvitations() async {
    if (!_isAuthenticated || (_activeUserId?.isEmpty ?? true)) return;
    try {
      pendingInvitations = await _repository.getPendingInvitations();
      CoupleInvitation? outgoingInvite;
      CoupleInvitation? acceptedInvite;
      for (final CoupleInvitation invitation in pendingInvitations) {
        if (outgoingInvite == null && invitation.isOutgoing && invitation.isPending) {
          outgoingInvite = invitation;
        }
        if (acceptedInvite == null && invitation.status == 'accepted') {
          acceptedInvite = invitation;
        }
      }
      outgoingContinuationInvite = outgoingInvite;
      if (acceptedInvite != null && _consumedAcceptedInviteIds.add(acceptedInvite.id)) {
        // A sheet dismissal is local only. An accepted continuation always wins.
        hiddenInvitationIds.remove(acceptedInvite.id);
        outgoingContinuationInvite = null;
        shouldOpenPreviousChoiceAfterInvite = true;
        previousChoiceAfterInviteWasUserAccepted = acceptedInvite.isIncoming;
        await loadCouple(force: true);
        AppLogger.info('[PairInvitation] accepted continuation converging to previous choices');
      }
      _safeNotify();
    } catch (e) {
      AppLogger.error('[InvitationSync] refresh failed', e);
    }
  }

  Future<CoupleInvitation?> createContinueAsBeforeInvite() async {
    if (outgoingContinuationInvite?.isPending == true) {
      return outgoingContinuationInvite;
    }
    try {
      final CoupleInvitation invite = await _repository.continueAsBefore();
      outgoingContinuationInvite = invite.isOutgoing && invite.isPending ? invite : null;
      if (invite.status == 'accepted' && _consumedAcceptedInviteIds.add(invite.id)) {
        hiddenInvitationIds.remove(invite.id);
        outgoingContinuationInvite = null;
        shouldOpenPreviousChoiceAfterInvite = true;
        previousChoiceAfterInviteWasUserAccepted = invite.isIncoming;
        await loadCouple(force: true);
      }
      await refreshInvitations();
      _safeNotify();
      return invite;
    } catch (e) {
      error = _mapError(e);
      _safeNotify();
      return null;
    }
  }

  Future<bool> startPairFilterChange() async {
    AppLogger.info('[PairFilterChange] local edit started');
    return true;
  }

  Future<bool> commitPairFilterChange() async {
    try {
      final Map<String, dynamic> response = await _repository.commitFilterChange();
      await loadCouple(force: true);
      final Object? eventId = response['eventId'] ?? response['generation'];
      final Object generation = response['generation'] ?? currentCouple?.lifecycleGeneration ?? 0;
      AppLogger.info('[PairFilterChange] committed event=$eventId generation=$generation by=self');
      return true;
    } catch (e) {
      error = _mapError(e);
      _safeNotify();
      return false;
    }
  }

  Future<void> acceptInvitation(CoupleInvitation invitation) async {
    final Couple? couple = await _repository.acceptInvitation(invitation.id);
    currentCouple = couple ?? await _repository.getMyCouple();
    _currentCoupleLoadedAt = DateTime.now();
    hiddenInvitationIds.add(invitation.id);
    pendingInvitations = pendingInvitations.where((CoupleInvitation item) => item.id != invitation.id).toList();
    if (hasCouple) {
      shouldOpenSessionResumeForResync = false;
      pairNeedsResyncMessage = null;
      startFilterStatePolling(reason: 'invitation_accept');
      await refreshFilterState(reason: 'invitation_accept');
    }
    shouldOpenPreviousChoiceAfterInvite = true;
    previousChoiceAfterInviteWasUserAccepted = true;
    _consumedAcceptedInviteIds.add(invitation.id);
    _safeNotify();
  }

  Future<void> declineInvitation(CoupleInvitation invitation) async {
    await _repository.declineInvitation(invitation.id);
    hiddenInvitationIds.add(invitation.id);
    pendingInvitations = pendingInvitations.where((CoupleInvitation item) => item.id != invitation.id).toList();
    _safeNotify();
  }

  void markPairNeedsResyncFromDeckError() {
    shouldOpenSessionResumeForResync = true;
    pairNeedsResyncMessage = 'Your pair session changed. Please continue together or start a new session.';
    _safeNotify();
  }

  bool consumeOpenSessionResumeForResync() {
    final bool shouldOpen = shouldOpenSessionResumeForResync;
    shouldOpenSessionResumeForResync = false;
    if (shouldOpen) _safeNotify();
    return shouldOpen;
  }

  bool consumeOpenPreviousChoiceAfterInvite() {
    final bool shouldOpen = shouldOpenPreviousChoiceAfterInvite;
    shouldOpenPreviousChoiceAfterInvite = false;
    previousChoiceAfterInviteWasUserAccepted = false;
    if (shouldOpen) _safeNotify();
    return shouldOpen;
  }

  bool consumeOpenPairFilterChange() {
    final bool shouldOpen = shouldOpenPairFilterChange;
    shouldOpenPairFilterChange = false;
    if (shouldOpen) _safeNotify();
    return shouldOpen;
  }

  void clearHandledFilterChangeMarkers({String reason = 'manual'}) {
    if (_handledFilterChangeGenerations.isNotEmpty) {
      AppLogger.info('[PairFilterChange] clearing provider handled generations reason=$reason');
    }
    _handledFilterChangeGenerations.clear();
  }

  void hideInvitationLocally(CoupleInvitation invitation) {
    hiddenInvitationIds.add(invitation.id);
    _safeNotify();
  }

  Duration get _pollInterval {
    if (_pollErrorStreak > 0) return const Duration(seconds: 10);
    if (!hasPartner) return const Duration(seconds: 3);
    if (bothConfirmed) return const Duration(seconds: 20);
    if (isMyChoicesConfirmed && !isPartnerReady) return const Duration(seconds: 3);
    return const Duration(seconds: 5);
  }


  void _detectPairLifecycleResync() {
    final Couple? couple = currentCouple;
    if (couple == null) {
      return;
    }
    if (couple.pairLifecycleStatus == 'filter_change_pending') {
      AppLogger.info('[PairFilterChange] notification skipped reason=local_editing event=${couple.lifecycleGeneration} generation=${couple.lifecycleGeneration}');
      return;
    }
    if (couple.pairLifecycleStatus == 'partner_action_required') {
      final String? changedBy = couple.lifecycleChangedBy;
      if (changedBy != null &&
          changedBy != _activeUserId &&
          _handledFilterChangeGenerations.add(couple.lifecycleGeneration)) {
        shouldOpenPairFilterChange = true;
        AppLogger.info('[PairFilterChange] partner committed event=${couple.lifecycleGeneration} generation=${couple.lifecycleGeneration}');
      }
      return;
    }
    if (couple.pairLifecycleStatus == 'active') {
      shouldOpenPairFilterChange = false;
    }
    if (couple.pairLifecycleStatus != 'needs_resync') {
      return;
    }
    final String? changedBy = couple.lifecycleChangedBy;
    if (changedBy == null || changedBy == _activeUserId) {
      return;
    }
    if (!_handledLifecycleGenerations.add(couple.lifecycleGeneration)) {
      return;
    }
    shouldOpenSessionResumeForResync = true;
    pairNeedsResyncMessage = 'Your partner left this session. You can wait for them to continue or start a new session.';
    AppLogger.info('[SessionSync] pair lifecycle needs resync generation=${couple.lifecycleGeneration}');
  }

  void _restartPollingIfNeeded({required String reason}) {
    if (!_pollingWanted || !_canPollFilterState) return;
    _stopPollingTimer(reason: reason);
    startFilterStatePolling(reason: reason);
  }

  void _restartPollingIfIntervalChanged() {
    if (_pollingSuspendedForDeckPrepare || !_pollingWanted || !_canPollFilterState || _pollTimer == null) return;
    if (_activePollInterval != _pollInterval) {
      _stopPollingTimer(reason: 'interval_change');
      startFilterStatePolling(reason: 'interval_change');
    }
  }

  void _stopPollingTimer({String? reason}) {
    final bool hadTimer = _pollTimer != null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _activePollInterval = null;
    if (reason != null && hadTimer) {
      AppLogger.info('[SessionSync] polling stopped reason=$reason');
    } else if (hadTimer) {
      AppLogger.info('[SessionSync] polling stopped');
    }
  }

  Future<void> _refreshCurrentCoupleAfterReset() async {
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    try {
      final Couple? loadedCouple = await _repository.getMyCouple();
      if (!_isCurrentSession(requestVersion, requestUserId)) return;
      currentCouple = loadedCouple;
      _currentCoupleLoadedAt = DateTime.now();
      _detectPairLifecycleResync();
      _sessionStateVersion++;
      if (!hasCouple) {
        _clearSessionState();
        return;
      }
      await refreshFilterState();
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _clearSessionState();
      } else {
        rethrow;
      }
    }
  }

  void resetForAuthBoundary({bool notify = true}) {
    stopInvitationPolling(reason: 'auth_boundary');
    clearSessionStateForLogout(notify: notify);
    shouldOpenPreviousChoiceAfterInvite = false;
    previousChoiceAfterInviteWasUserAccepted = false;
    shouldOpenSessionResumeForResync = false;
    shouldOpenPairFilterChange = false;
    pairNeedsResyncMessage = null;
  }

  void handleAuthBoundary(int version) {
    if (_authBoundaryVersion == version) {
      return;
    }
    _authBoundaryVersion = version;
    resetForAuthBoundary(notify: false);
  }

  void clearSessionStateForLogout({bool notify = true}) {
    _clearSessionState();
    isLoading = false;
    _isRefreshingCurrentCouple = false;
    _isRefreshingFilterState = false;
    _filterStateRefreshFuture = null;
    pendingInvitations = <CoupleInvitation>[];
    outgoingContinuationInvite = null;
    hiddenInvitationIds.clear();
    shouldOpenSessionResumeForResync = false;
    pairNeedsResyncMessage = null;
    AppLogger.info('[CoupleProvider] session state cleared for logout');
    if (notify) {
      _safeNotify();
    }
  }

  void _clearSessionState({
    bool incrementVersion = true,
    bool clearEndedMessage = true,
  }) {
    stopFilterStatePolling(reason: 'session_clear');
    currentCouple = null;
    hiddenInvitationIds.clear();
    outgoingContinuationInvite = null;
    shouldOpenPairFilterChange = false;
    _handledFilterChangeGenerations.clear();
    _currentCoupleLoadedAt = null;
    _clearFilterState();
    _filterStateRefreshFuture = null;
    error = null;
    if (clearEndedMessage) {
      sessionEndedMessage = null;
    }
    _joinInFlight = false;
    _leaveInFlight = false;
    if (incrementVersion) {
      _sessionStateVersion++;
    }
  }

  void _clearFilterState() {
    _filterState = null;
  }

  void clearSessionEndedMessage() {
    sessionEndedMessage = null;
    _safeNotify();
  }

  void _handleSessionEndedIfNeeded({
    required bool previouslyHadSession,
    bool incrementVersion = true,
  }) {
    if (previouslyHadSession) {
      sessionEndedMessage = partnerLeftSessionMessage;
      AppLogger.info('[SessionSync] pair session ended or partner left');
    }
    _clearSessionState(incrementVersion: incrementVersion, clearEndedMessage: false);
  }

  Future<void> _refreshActiveSessionAfterConflict() async {
    final int requestVersion = _sessionStateVersion;
    final String? requestUserId = _activeUserId;
    try {
      final Couple? loadedCouple = await _repository.getMyCouple();
      if (!_isCurrentSession(requestVersion, requestUserId)) return;
      currentCouple = loadedCouple;
      _currentCoupleLoadedAt = DateTime.now();
      _detectPairLifecycleResync();
      if (hasCouple) {
        _sessionStateVersion++;
        await refreshFilterState();
      } else {
        _clearSessionState();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        _clearSessionState();
      } else {
        AppLogger.error('[CoupleProvider] failed to refresh active session after 409', e);
      }
    } catch (e) {
      AppLogger.error('[CoupleProvider] failed to refresh active session after 409', e);
    }
  }

  bool _isActiveSessionConflict(ApiException e) {
    return e.statusCode == 409 && e.message.toLowerCase().contains('active session');
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  bool _isCurrentSession(int version, String? userId, {String? coupleId}) {
    final bool matches = !_disposed &&
        version == _sessionStateVersion &&
        userId == _activeUserId &&
        (coupleId == null || coupleId == currentCouple?.id);
    if (!matches) {
      AppLogger.info('[SessionSync] stale response ignored sessionVersion=$version current=$_sessionStateVersion');
    }
    return matches;
  }

  String _syncErrorMessage(Object e) {
    if (e is ApiException && _isPairSessionInactive(e)) {
      return partnerLeftSessionMessage;
    }
    if (e is ApiException && e.statusCode == 404) return 'Create or join a session';
    if (e is ApiException && (e.message.toLowerCase().contains('timeout') || e.message.toLowerCase().contains('internet'))) {
      return 'Connection is slow. We’ll keep checking.';
    }
    return 'We’re having trouble syncing. We’ll keep checking.';
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return switch (e.code) {
        'INVALID_INVITE_CODE' => invalidInviteCodeMessage,
        'SESSION_FULL' => sessionFullMessage,
        'SESSION_INACTIVE' => sessionInactiveMessage,
        'ALREADY_IN_TARGET_SESSION' => activeSessionMessage,
        'CANNOT_JOIN_OWN_SESSION' => ownSessionMessage,
        'ACTIVE_SESSION_HAS_PARTNER' => activeSessionHasPartnerMessage,
        'ACTIVE_SOLO_SESSION_EXISTS' => activeSoloSessionMessage,
        'PREVIOUS_PARTNER_NOT_FOUND' => 'No previous pair setup found.',
        _ => ErrorMessages.fromApiException(e),
      };
    }
    return ErrorMessages.fromException(e);
  }

  bool _isPairSessionInactive(ApiException e) {
    final String lower = e.message.toLowerCase();
    return e.statusCode == 404 || e.statusCode == 409 || lower.contains('pair_session_inactive') || lower.contains('no active paired session') || lower.contains('no active session');
  }
}
