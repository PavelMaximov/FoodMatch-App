import 'package:flutter/foundation.dart';

/// Emits one-shot visual events for the bottom navigation without owning badge data.
class NavBadgeAnimationController extends ChangeNotifier {
  int _soloMatchesPlusOneEvent = 0;

  int get soloMatchesPlusOneEvent => _soloMatchesPlusOneEvent;

  void showSoloMatchesPlusOne() {
    _soloMatchesPlusOneEvent++;
    notifyListeners();
  }
}
