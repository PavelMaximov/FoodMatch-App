import 'package:flutter/foundation.dart';

/// Emits one-shot visual events for the bottom navigation without owning badge data.
class NavBadgeAnimationController extends ChangeNotifier {
  int _soloMatchesPlusOneEvent = 0;
  final Set<String> _animatedMatchEvents = <String>{};

  int get soloMatchesPlusOneEvent => _soloMatchesPlusOneEvent;

  bool showSoloMatchesPlusOne({String? eventKey}) {
    if (eventKey != null && !_animatedMatchEvents.add(eventKey)) return false;
    if (kDebugMode) {
      debugPrint(
        '[NavBadgeAnim] trigger soloPlusOne eventKey=${eventKey ?? 'none'}',
      );
    }
    _soloMatchesPlusOneEvent++;
    notifyListeners();
    return true;
  }

  void resetSessionEvents() => _animatedMatchEvents.clear();
}
