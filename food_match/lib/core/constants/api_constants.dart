import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static const String health = '/health';
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String coupleCreate = '/api/couples/create';
  static const String coupleJoin = '/api/couples/join';
  static const String coupleMe = '/api/couples/me';
  static const String coupleReset = '/api/couples/reset';
  static const String coupleLeave = '/api/couples/leave';
  static const String dishes = '/api/dishes';
  static const String swipes = '/api/swipes';
  static const String swipeStats = '/api/swipes/me/stats';
  static const String swipeMatches = '/api/swipes/matches';
  static const String recipes = '/api/recipes';
  static const String uploads = '/api/uploads';
}
