import 'package:flutter/foundation.dart';

class AppLogger {
  static void api(String method, String url, {int? statusCode, String? body}) {
    if (kDebugMode) {
      print('🌐 $method $url');
      if (statusCode != null) print('   ↳ Status: $statusCode');
      if (body != null && body.length < 500) {
        final String maskedBody = body.replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[JWT_MASKED]',
        );
        print('   ↳ Body: $maskedBody');
      }
    }
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      print('❌ $message');
      if (error != null) print('   ↳ $error');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      print('ℹ️ $message');
    }
  }
}
