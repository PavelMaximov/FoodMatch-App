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
  final Map<String, PartnerSessionChoices> _sessionChoicesByUser =
      <String, PartnerSessionChoices>{};

  bool get hasCouple => currentCouple != null;
  String? get inviteCode => currentCouple?.inviteCode;
  int get sessionStateVersion => _sessionStateVersion;

  Future<void> loadCouple() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentCouple = await _repository.getMyCouple();
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
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
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
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
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
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
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
      currentCouple = null;
      _sessionStateVersion++;
      _sessionChoicesByUser.clear();
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
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}
