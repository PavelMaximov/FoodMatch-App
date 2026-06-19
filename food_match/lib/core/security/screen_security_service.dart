import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenSecurityService {
  ScreenSecurityService._();

  static final ScreenSecurityService instance = ScreenSecurityService._();
  static const MethodChannel _channel = MethodChannel('foodmatch/screen_security');
  bool _enabled = false;

  Future<void> setSecureScreenEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(enabled ? 'enableSecureScreen' : 'disableSecureScreen');
    } on PlatformException catch (error) {
      _enabled = !enabled;
      if (kDebugMode) {
        debugPrint('[ScreenSecurity] FLAG_SECURE toggle failed: ${error.message}');
      }
    }
  }
}
