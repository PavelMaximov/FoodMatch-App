import 'package:flutter/foundation.dart';

/// Serializes card animations and Undo, including resets across auth changes.
class SwipeActionController extends ChangeNotifier {
  bool _busy = false;
  bool _disposed = false;
  int _generation = 0;

  bool get isBusy => _busy;

  Future<void> run(Future<void> Function() action) async {
    if (_disposed || _busy) return;
    final generation = _generation;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      if (!_disposed && generation == _generation) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _generation++;
    _busy = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
