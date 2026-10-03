import 'package:flutter/widgets.dart';

/// Coalesces rebuild-triggered effects and invalidates queued work on reset.
class SwipeEffectScheduler {
  final Map<String, VoidCallback> _pending = <String, VoidCallback>{};
  int _generation = 0;
  bool _disposed = false;

  void schedule(String key, VoidCallback effect) {
    if (_disposed) return;
    final alreadyQueued = _pending.containsKey(key);
    _pending[key] = effect;
    if (alreadyQueued) return;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || generation != _generation) return;
      _pending.remove(key)?.call();
    });
  }

  void reset() {
    _generation++;
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
