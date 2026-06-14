import 'package:flutter/foundation.dart';

class AppLogger {
  static const int _maxBodyLogChars = 1200;

  static void api(
    String method,
    String url, {
    int? statusCode,
    int? durationMs,
    String? body,
    String? errorType,
  }) {
    if (!kDebugMode) return;

    final Uri? uri = Uri.tryParse(url);
    final String path = uri == null
        ? url
        : uri.hasQuery
            ? '${uri.path}?${uri.query}'
            : uri.path;

    if (statusCode == null) {
      debugPrint('🌐 $method $path');
      return;
    }

    final bool ok = statusCode >= 200 && statusCode < 300;
    final String icon = ok ? '✅' : '❌';
    final String duration = durationMs == null ? '' : ' ${durationMs}ms';
    final String error = errorType == null ? '' : ' $errorType';
    debugPrint('$icon $statusCode$duration $path$error');

    final String? safeBody = _safeBody(body);
    if (safeBody != null) {
      debugPrint('   ↳ Body: $safeBody');
    }
  }

  static void error(String message, [dynamic error]) {
    if (kDebugMode) {
      debugPrint('❌ $message');
      if (error != null) debugPrint('   ↳ $error');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ $message');
    }
  }

  static String? _safeBody(String? body) {
    if (body == null || body.isEmpty) return null;
    final String masked = body
        .replaceAll(
          RegExp(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
          '[JWT_MASKED]',
        )
        .replaceAll(
          RegExp(r'("password"\s*:\s*").*?"', caseSensitive: false),
          r'$1[MASKED]"',
        )
        .replaceAll(
          RegExp(r'("token"\s*:\s*").*?"', caseSensitive: false),
          r'$1[MASKED]"',
        );
    if (masked.length <= _maxBodyLogChars) return masked;
    return '${masked.substring(0, _maxBodyLogChars)}… [truncated ${masked.length - _maxBodyLogChars} chars]';
  }
}
