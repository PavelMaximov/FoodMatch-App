import 'dart:async';

/// Owns screen polling timers. A channel never overlaps its own request.
class SwipePollingController {
  SwipePollingController({required this.onError});

  final void Function(Object, StackTrace) onError;
  final Map<String, Timer> _timers = <String, Timer>{};
  final Set<String> _inFlight = <String>{};
  bool _disposed = false;

  void start(String channel, Duration interval, Future<void> Function() poll) {
    if (_disposed || _timers.containsKey(channel)) return;
    _timers[channel] = Timer.periodic(interval, (_) => unawaited(run(channel, poll)));
  }

  Future<void> run(String channel, Future<void> Function() poll) async {
    if (_disposed || !_inFlight.add(channel)) return;
    try {
      await poll();
    } catch (error, stack) {
      if (!_disposed) onError(error, stack);
    } finally {
      _inFlight.remove(channel);
    }
  }

  void stop(String channel) => _timers.remove(channel)?.cancel();

  void stopAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() {
    _disposed = true;
    stopAll();
  }
}
