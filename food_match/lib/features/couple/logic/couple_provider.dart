import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/couple.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';

class PartnerSessionChoices {
  const PartnerSessionChoices({
    this.cuisines = const <String>[],
    this.moods = const <String>[],
    this.blocked = const <String>[],
    this.diet = const <String>[],
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> blocked;
  final List<String> diet;
}

class CoupleProvider extends ChangeNotifier {
  CoupleProvider({required CoupleRepository repository}) : _repository = repository;

  final CoupleRepository _repository;

  Couple? currentCouple;
  bool isLoading = false;
  String? error;
  int _sessionStateVersion = 0;
  String? _activeUserId;
  Timer? _pollTimer;
  SessionFilterState? _sessionFilterState;
  final Map<String, PartnerSessionChoices> _sessionChoicesByUser =
      <String, PartnerSessionChoices>{};

  bool get hasCouple => currentCouple != null;
  String? get inviteCode => currentCouple?.inviteCode;
  int get sessionStateVersion => _sessionStateVersion;
  SessionFilterState? get sessionFilterState => _sessionFilterState;

  Future<void> loadCouple() async {
    if (_activeUserId == null) {
      currentCouple = null;
      _sessionFilterState = null;
      _sessionChoicesByUser.clear();
      _stopPolling();
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentCouple = await _repository.getMyCouple();
      if (currentCouple == null) {
        _sessionFilterState = null;
        _sessionChoicesByUser.clear();
        _stopPolling();
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        currentCouple = null;
      } else {
        error = _mapError(e);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCouple() async {
    if (isLoading || currentCouple != null) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentCouple = await _repository.create();
      _stopPolling();
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
      _sessionFilterState = null;
    } on ApiException catch (e) {
      final String normalized = e.message.toLowerCase();
      final bool isAlreadyInCouple = e.statusCode == 409 &&
          (normalized.contains('already has an active session') ||
              normalized.contains('already in couple'));

      if (isAlreadyInCouple) {
        try {
          currentCouple = await _repository.getMyCouple();
          error = null;
        } catch (loadError) {
          error = _mapError(loadError);
        }
      } else {
        error = _mapError(e);
      }
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinCouple(String inviteCode) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentCouple = await _repository.join(inviteCode);
      _stopPolling();
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
      _sessionFilterState = null;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetCouple() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repository.reset();
      _stopPolling();
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
      _sessionFilterState = null;
      await loadCouple();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveCouple() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _repository.leave();
      _stopPolling();
      currentCouple = null;
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
      _sessionFilterState = null;
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }



  void setMySessionChoices(
    String userId, {
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
  }) {
    if (userId.isEmpty) {
      return;
    }
    _sessionChoicesByUser[userId] = PartnerSessionChoices(
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
      diet: diet,
    );
    notifyListeners();
  }

  PartnerSessionChoices partnerChoicesFor(String userId) {
    if (currentCouple == null) {
      return const PartnerSessionChoices();
    }

    final List<String> memberIds = currentCouple!.members;
    final String? partnerId = memberIds.firstWhere(
      (String id) => id != userId,
      orElse: () => '',
    );

    if (partnerId == null || partnerId.isEmpty) {
      return const PartnerSessionChoices();
    }

    return _sessionChoicesByUser[partnerId] ?? const PartnerSessionChoices();
  }

  void clearSessionChoices() {
    _sessionChoicesByUser.clear();
    _sessionFilterState = null;
    _stopPolling();
    notifyListeners();
  }

  Future<void> startFilterStatePolling() async {
    if (_activeUserId == null || currentCouple == null) {
      _stopPolling();
      return;
    }
    _stopPolling();
    await refreshFilterState();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshFilterState();
    });
  }

  void stopFilterStatePolling() {
    _stopPolling();
  }

  Future<void> refreshFilterState() async {
    if (_activeUserId == null || currentCouple == null) {
      _stopPolling();
      return;
    }
    try {
      final SessionFilterState? state = await _repository.getFilterState();
      _sessionFilterState = state;
      _syncChoicesFromFilterState();
      notifyListeners();
    } catch (_) {
      // Keep UI responsive if polling fails temporarily.
    }
  }

  Future<void> pushSessionDraft({
    required String userId,
    required int step,
    required List<String> cuisines,
    required List<String> moods,
    required List<String> blocked,
    required List<String> diet,
    required bool confirmed,
  }) async {
    if (_activeUserId == null || currentCouple == null || userId.isEmpty) {
      return;
    }

    setMySessionChoices(
      userId,
      cuisines: cuisines,
      moods: moods,
      blocked: blocked,
      diet: diet,
    );

    try {
      _sessionFilterState = await _repository.updateFilterState(
        step: step,
        cuisines: cuisines,
        moods: moods,
        blocked: blocked,
        diet: diet,
        confirmed: confirmed,
      );
      _syncChoicesFromFilterState();
      notifyListeners();
    } catch (_) {
      // ignore transient update errors for MVP flow
    }
  }

  Future<void> clearRemoteFilterState() async {
    if (currentCouple != null) {
      try {
        await _repository.clearFilterState();
      } catch (_) {
        // no-op
      }
    }
    _sessionFilterState = null;
    _sessionChoicesByUser.clear();
    _stopPolling();
    notifyListeners();
  }

  void handleAuthChanged(String? userId) {
    if (_activeUserId == userId) {
      return;
    }

    _activeUserId = userId;
    _stopPolling();
    currentCouple = null;
    _sessionFilterState = null;
    _sessionChoicesByUser.clear();
    _sessionStateVersion++;
    error = null;
    notifyListeners();
  }

  bool hasConfirmed(String userId) {
    final SessionFilterDraft? draft = _findDraftForUser(userId);
    return draft?.confirmed == true;
  }

  bool isPartnerConfirmed(String userId) {
    final String? partnerId = _partnerIdFor(userId);
    if (partnerId == null) {
      return false;
    }
    final SessionFilterDraft? draft = _findDraftForUser(partnerId);
    return draft?.confirmed == true;
  }

  int overallCompatibility({required String userId}) {
    final PartnerSessionChoices partner = partnerChoicesFor(userId);
    final PartnerSessionChoices mine = _sessionChoicesByUser[userId] ?? const PartnerSessionChoices();
    final double step1 = _computeOverlap(mine.cuisines, partner.cuisines, anyAsNeutral: true);
    final double step2 = _computeOverlap(mine.moods, partner.moods);
    final double step3 = _computeExceptions(mine.blocked, partner.blocked);
    return (((step1 + step2 + step3) / 3) * 100).round();
  }

  int stepCompatibility({required int step, required String userId}) {
    final PartnerSessionChoices partner = partnerChoicesFor(userId);
    final PartnerSessionChoices mine = _sessionChoicesByUser[userId] ?? const PartnerSessionChoices();
    if (step == 1) {
      return (_computeOverlap(mine.cuisines, partner.cuisines, anyAsNeutral: true) * 100).round();
    }
    if (step == 2) {
      return (_computeOverlap(mine.moods, partner.moods) * 100).round();
    }
    return (_computeExceptions(mine.blocked, partner.blocked) * 100).round();
  }

  double _computeOverlap(List<String> left, List<String> right, {bool anyAsNeutral = false}) {
    if (left.isEmpty && right.isEmpty) {
      return 1;
    }
    if (left.isEmpty || right.isEmpty) {
      return 0.5;
    }
    if (anyAsNeutral && (left.contains('Any') || right.contains('Any'))) {
      return 0.9;
    }
    final Set<String> union = <String>{...left, ...right};
    final int intersection = left.where((String item) => right.contains(item)).length;
    return union.isEmpty ? 1 : intersection / union.length;
  }

  double _computeExceptions(List<String> left, List<String> right) {
    if (left.isEmpty && right.isEmpty) {
      return 1;
    }
    if (left.isEmpty || right.isEmpty) {
      return 0.6;
    }
    final Set<String> union = <String>{...left, ...right};
    final int overlap = left.where((String item) => right.contains(item)).length;
    return union.isEmpty ? 1 : (0.6 + (overlap / union.length) * 0.4);
  }

  String? _partnerIdFor(String userId) {
    if (currentCouple == null) {
      return null;
    }
    final List<String> memberIds = currentCouple!.members;
    final String partnerId = memberIds.firstWhere(
      (String id) => id != userId,
      orElse: () => '',
    );
    return partnerId.isEmpty ? null : partnerId;
  }

  void _syncChoicesFromFilterState() {
    final SessionFilterState? state = _sessionFilterState;
    if (state == null) {
      return;
    }
    for (final SessionFilterDraft draft in state.drafts) {
      _sessionChoicesByUser[draft.userId] = PartnerSessionChoices(
        cuisines: draft.cuisines,
        moods: draft.moods,
        blocked: draft.blocked,
        diet: draft.diet,
      );
    }
  }

  SessionFilterDraft? _findDraftForUser(String userId) {
    final SessionFilterState? state = _sessionFilterState;
    if (state == null) {
      return null;
    }
    for (final SessionFilterDraft draft in state.drafts) {
      if (draft.userId == userId) {
        return draft;
      }
    }
    return null;
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}
