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
  CoupleFilterState _filterState = const CoupleFilterState(
    myChoices: CoupleFilterChoices(),
    bothConfirmed: false,
    compatibility: 0,
    status: 'draft',
  );
  Timer? _pollTimer;
  bool _disposed = false;
  bool _joinInFlight = false;

  bool isLoading = false;
  String? error;
  int _sessionStateVersion = 0;

  bool get hasCouple => currentCouple != null;
  String? get inviteCode => currentCouple?.inviteCode;
  int get sessionStateVersion => _sessionStateVersion;
  CoupleFilterChoices get myChoices => _filterState.myChoices;
  CoupleFilterChoices? get partnerChoices => _filterState.partnerChoices;
  bool get bothConfirmed => _filterState.bothConfirmed;
  int get compatibility => _filterState.compatibility;
  bool get isPartnerReady => _filterState.partnerChoices?.confirmed == true;
  bool get isMyChoicesConfirmed => _filterState.myChoices.confirmed;
  bool get isJoining => _joinInFlight;
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
      if (currentCouple != null) {
        await refreshFilterState();
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        currentCouple = null;
      } else {
        error = _mapError(e);
      }
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> createCouple() async {
    if (isLoading || currentCouple != null) return;
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
    if (currentCouple != null) {
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
      currentCouple = await _repository.getMyCouple();
      _sessionStateVersion++;
      await refreshFilterState();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> leaveCouple() async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _safeNotify();
    try {
      await _repository.leave();
      currentCouple = null;
      _filterState = const CoupleFilterState(
        myChoices: CoupleFilterChoices(),
        bothConfirmed: false,
        compatibility: 0,
        status: 'draft',
      );
      _sessionStateVersion++;
      stopFilterStatePolling();
    } catch (e) {
      error = _mapError(e);
    } finally {
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
      final previousPartnerConfirmed = _filterState.partnerChoices?.confirmed == true;
      _filterState = await _repository.getFilterState();
      AppLogger.info('[CoupleFilterState] loaded status=${_filterState.status} bothConfirmed=${_filterState.bothConfirmed}');
      if (!previousPartnerConfirmed && (_filterState.partnerChoices?.confirmed == true)) {
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

  Future<void> _refreshActiveSessionAfterConflict() async {
    try {
      currentCouple = await _repository.getMyCouple();
      if (currentCouple != null) {
        _sessionStateVersion++;
        await refreshFilterState();
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
