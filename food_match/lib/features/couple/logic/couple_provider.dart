import 'package:flutter/foundation.dart';

import '../../../data/models/couple.dart';
import '../../../data/repositories/couple_repository.dart';
import '../../../data/services/api_service.dart';

class CoupleProvider extends ChangeNotifier {
  CoupleProvider({required CoupleRepository repository}) : _repository = repository;

  final CoupleRepository _repository;

  Couple? currentCouple;
  bool isLoading = false;
  String? error;

  bool get hasCouple => currentCouple != null;
  String? get inviteCode => currentCouple?.inviteCode;

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
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      currentCouple = await _repository.create();
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
    return 'Unexpected error occurred';
  }
}
