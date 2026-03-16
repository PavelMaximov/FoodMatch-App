import 'package:flutter/foundation.dart';

class AppLogger {
  static void api(String method, String url, {int? statusCode, String? body}) {
    if (kDebugMode) {
      print('🌐 $method $url');
      if (statusCode != null) print('   ↳ Status: $statusCode');
      if (body != null && body.length < 500) print('   ↳ Body: $body');
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
