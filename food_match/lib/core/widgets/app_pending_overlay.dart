import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'food_match_loader.dart';

class PendingOverlayController extends ChangeNotifier {
  static const Duration showDelay = Duration(milliseconds: 180);
  static const Duration minimumVisibleDuration = Duration(milliseconds: 350);
  static const Duration defaultTimeout = Duration(seconds: 15);

  final Map<int, String?> _operations = <int, String?>{};
  int _nextToken = 0;
  Timer? _showTimer;
  DateTime? _shownAt;
  bool _visible = false;

  bool get isVisible => _visible;
  String? get message =>
      _operations.isEmpty ? null : _operations.values.last;

  int show({String? message}) {
    final int token = ++_nextToken;
    _operations[token] = message;
    debugPrint('[PendingOverlay] show message=${message ?? 'Loading...'} token=$token');
    if (_visible) notifyListeners();
    _showTimer ??= Timer(showDelay, () {
      _showTimer = null;
      if (_operations.isEmpty) return;
      _visible = true;
      _shownAt = DateTime.now();
      notifyListeners();
    });
    return token;
  }

  Future<void> hide(int token) async {
    if (!_operations.containsKey(token)) return;
    _operations.remove(token);
    debugPrint('[PendingOverlay] hide token=$token');
    if (_operations.isNotEmpty) {
      notifyListeners();
      return;
    }
    _showTimer?.cancel();
    _showTimer = null;
    if (!_visible) return;
    final Duration elapsed = DateTime.now().difference(_shownAt!);
    final Duration remaining = minimumVisibleDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (_operations.isEmpty) {
      _visible = false;
      _shownAt = null;
      notifyListeners();
    }
  }

  Future<T> run<T>({
    required String message,
    required Future<T> Function() operation,
    Duration timeout = defaultTimeout,
  }) async {
    final int token = show(message: message);
    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          debugPrint('[PendingOverlay] timeout token=$token');
          throw TimeoutException('Blocking operation timed out', timeout);
        },
      );
    } finally {
      await hide(token);
    }
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }
}

class AppPendingOverlay extends StatelessWidget {
  const AppPendingOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final PendingOverlayController controller =
        context.watch<PendingOverlayController>();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (controller.isVisible)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.4),
              child: const ModalBarrier(
                dismissible: false,
                color: Colors.transparent,
              ),
            ),
          ),
        if (controller.isVisible)
          Center(
            child: FoodMatchLoader(
              size: 96,
              label: controller.message,
              dimmed: true,
            ),
          ),
      ],
    );
  }
}
