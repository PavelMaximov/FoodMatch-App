import 'package:flutter/foundation.dart';

import '../../../data/models/match_history.dart';
import '../../../data/repositories/match_history_repository.dart';

class MatchHistoryProvider extends ChangeNotifier {
  MatchHistoryProvider({required MatchHistoryRepository repository})
    : _repository = repository;

  MatchHistoryProvider.seeded(MatchHistory seeded) : _repository = null {
    history = seeded;
  }

  final MatchHistoryRepository? _repository;
  MatchHistory history = const MatchHistory(solo: [], pair: []);
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      history = await _repository!.getHistory();
    } catch (_) {
      error = 'Unable to load match history.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
