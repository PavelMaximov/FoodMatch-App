import 'package:flutter/foundation.dart';

import '../../../core/constants/app_strings.dart';
import '../../../data/models/couple.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';

class CoupleProvider extends ChangeNotifier {
  CoupleProvider({required CoupleRepository repository}) : _repository = repository;

  final CoupleRepository _repository;

  Couple? currentCouple;
  bool isLoading = false;
  String? error;
  int _sessionStateVersion = 0;

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
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}
