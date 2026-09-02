import 'package:flutter/foundation.dart';

import '../../../data/models/match_history.dart';
import '../../../data/repositories/match_history_repository.dart';

class MatchHistoryProvider extends ChangeNotifier {
  MatchHistoryProvider({required MatchHistoryRepository repository})
    : _loadHistory = repository.getHistory;

  @visibleForTesting
  MatchHistoryProvider.withLoader(Future<MatchHistory> Function() loader)
    : _loadHistory = loader;

  MatchHistoryProvider.seeded(MatchHistory seeded)
    : _loadHistory = (() async => seeded) {
    history = seeded;
  }

  final Future<MatchHistory> Function() _loadHistory;
  MatchHistory history = const MatchHistory(solo: [], pair: []);
  bool isLoading = false;
  String? error;
  bool _disposed = false;
  int _requestId = 0;

  Future<void> load() async {
    final int requestId = ++_requestId;
    if (_disposed) return;
    isLoading = true;
    error = null;
    _safeNotifyListeners();
    try {
      final MatchHistory loaded = await _loadHistory();
      if (_disposed || requestId != _requestId) return;
      history = loaded;
    } catch (_) {
      if (_disposed || requestId != _requestId) return;
      error = 'Unable to load match history.';
    } finally {
      if (!_disposed && requestId == _requestId) {
        isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestId++;
    super.dispose();
  }
}
