import 'dart:async';

/// Shares the complete operation, including fallback and cleanup, with callers.
/// Invalidation detaches old work without letting it clear a newer request.
class SingleFlight<T> {
  Future<T>? _pending;
  int _generation = 0;

  int get generation => _generation;
  bool isCurrent(int generation) => generation == _generation;

  Future<T> run(Future<T> Function() operation) {
    final pending = _pending;
    if (pending != null) return pending;
    final completer = Completer<T>();
    _pending = completer.future;
    // Publish before invoking code that may synchronously notify listeners.
    completer.complete(
      Future<T>.sync(operation).whenComplete(() {
        if (identical(_pending, completer.future)) _pending = null;
      }),
    );
    return completer.future;
  }

  void invalidate() {
    _generation++;
    _pending = null;
  }
}
