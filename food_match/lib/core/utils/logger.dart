import 'dart:convert';

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

    final String? summary = _bodySummary(path, body);
    if (summary != null) {
      debugPrint('   ↳ Body summary: $summary');
      return;
    }

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

  static String? _bodySummary(String path, String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final dynamic dishes = decoded['dishes'];
      if (dishes is List<dynamic>) return 'dishes=${dishes.length}';

      final dynamic items = decoded['items'];
      if (items is List<dynamic>) {
        final dynamic total = decoded['total'];
        final dynamic hasMore = decoded['hasMore'];
        final List<String> parts = <String>['items=${items.length}'];
        if (total != null) parts.add('total=$total');
        if (hasMore != null) parts.add('hasMore=$hasMore');
        return parts.join(' ');
      }

      final dynamic matches = decoded['matches'];
      if (matches is List<dynamic>) return 'matches=${matches.length}';

      final dynamic deckDishes = decoded['deck'] is Map<String, dynamic>
          ? (decoded['deck'] as Map<String, dynamic>)['dishes']
          : null;
      if (deckDishes is List<dynamic>) return 'deckDishes=${deckDishes.length}';

      if (path.contains('/api/couples/deck/prepare')) {
        final dynamic preparedDishes = decoded['preparedDeck'] is Map<String, dynamic>
            ? (decoded['preparedDeck'] as Map<String, dynamic>)['dishes']
            : decoded['dishes'];
        if (preparedDishes is List<dynamic>) {
          return 'preparedDeckDishes=${preparedDishes.length}';
        }
      }
    } catch (_) {
      return null;
    }
    return null;
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
    final String preview = masked.substring(0, _maxBodyLogChars);
    return '<truncated length=${masked.length} preview="$preview…">';
  }
}
