import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/couple.dart';
import '../../../data/models/couple_filter_state.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';

class CoupleProvider extends ChangeNotifier {
  CoupleProvider({required CoupleRepository repository}) : _repository = repository;

  static const String activeSessionMessage = 'You already have an active session.';

  final CoupleRepository _repository;
  Couple? currentCouple;
  CoupleFilterState? _filterState;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _joinInFlight = false;
  bool _leaveInFlight = false;

  bool isLoading = false;
  String? error;
  int _sessionStateVersion = 0;

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
  bool get isJoining => _joinInFlight;
  bool get isLeaving => _leaveInFlight;
  bool get hasActiveSessionConflict => error == activeSessionMessage;

  @override
  void dispose() {
    _disposed = true;
    stopFilterStatePolling();
    super.dispose();
  }

  Future<void> loadCouple() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      currentCouple = await _repository.getMyCouple();
      if (hasCouple) {
        await refreshFilterState();
      } else {
        currentCouple = null;
        _clearFilterState();
        stopFilterStatePolling();
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        _clearSessionState(incrementVersion: false);
      } else {
        error = _mapError(e);
      }
    } finally {
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
      _sessionStateVersion++;
      await refreshFilterState();
    } on ApiException catch (e) {
      error = _mapError(e);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> joinCouple(String inviteCode) async {
    if (_joinInFlight || isLoading) return;
    if (hasCouple) {
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
      currentCouple = await _repository.join(inviteCode);
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
      _joinInFlight = false;
      isLoading = false;
      _safeNotify();
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
    try {
      await _repository.leave();
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
    _filterState = await _repository.updateMyFilterState(
      CoupleFilterChoices(cuisines: cuisines, moods: moods, diet: diet, exclusions: exclusions),
    );
    AppLogger.info('[CoupleFilterState] saved my choices');
    _safeNotify();
  }

  Future<void> confirmMyChoices() async {
    _filterState = await _repository.confirmMyFilterState();
    _safeNotify();
  }

  Future<void> refreshFilterState() async {
    if (!hasCouple) return;
    try {
      final previousPartnerConfirmed = _filterState?.partnerChoices?.confirmed == true;
      final CoupleFilterState nextState = await _repository.getFilterState();
      _filterState = nextState;
      AppLogger.info('[CoupleFilterState] loaded status=${nextState.status} bothConfirmed=${nextState.bothConfirmed}');
      if (!previousPartnerConfirmed && (nextState.partnerChoices?.confirmed == true)) {
        AppLogger.info('[CoupleFilterState] partner confirmed=true');
      }
      _safeNotify();
    } catch (_) {}
  }

  void startFilterStatePolling() {
    if (!hasCouple || _pollTimer != null) return;
    AppLogger.info('[CoupleFilterState] polling started');
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => refreshFilterState());
  }

  void stopFilterStatePolling() {
    if (_pollTimer == null) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    AppLogger.info('[CoupleFilterState] polling stopped');
  }


  Future<void> _refreshCurrentCoupleAfterReset() async {
    try {
      currentCouple = await _repository.getMyCouple();
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

  void _clearSessionState({bool incrementVersion = true}) {
    stopFilterStatePolling();
    currentCouple = null;
    _clearFilterState();
    error = null;
    _joinInFlight = false;
    _leaveInFlight = false;
    if (incrementVersion) {
      _sessionStateVersion++;
    }
  }

  void _clearFilterState() {
    _filterState = null;
  }

  Future<void> _refreshActiveSessionAfterConflict() async {
    try {
      currentCouple = await _repository.getMyCouple();
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

  String _mapError(Object e) => e is ApiException ? e.message : AppStrings.unexpectedError;
}
