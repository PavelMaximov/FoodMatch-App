import 'package:flutter/foundation.dart';

import '../../../core/async/single_flight.dart';

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
  final _load = SingleFlight<void>();

  Future<void> load() {
    if (_disposed) return Future<void>.value();
    return _load.run(_loadOnce);
  }

  Future<void> _loadOnce() async {
    final generation = _load.generation;
    isLoading = true;
    error = null;
    _safeNotifyListeners();
    try {
      final MatchHistory loaded = await _loadHistory();
      if (_disposed || !_load.isCurrent(generation)) return;
      history = loaded;
    } catch (_) {
      if (_disposed || !_load.isCurrent(generation)) return;
      error = 'Unable to load match history.';
    } finally {
      if (!_disposed && _load.isCurrent(generation)) {
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
    _load.invalidate();
    super.dispose();
  }
}
