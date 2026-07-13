import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static const int _defaultPort = 4000;
  static const String _androidEmulatorBaseUrl = 'http://10.0.2.2:4000';
  static const String _physicalAndroidFallbackBaseUrl = 'http://192.168.0.39:4000';
  static const String _desktopBaseUrl = 'http://localhost:4000';
  static const bool _forceAndroidEmulator = bool.fromEnvironment('ANDROID_EMULATOR', defaultValue: false);
  static const bool _hasEnvBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '').length > 0;

  static String get baseUrl {
    const String envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (envBaseUrl.trim().isNotEmpty) {
      return _trimTrailingSlash(envBaseUrl.trim());
    }

    if (kIsWeb) {
      final String host = Uri.base.host;
      final String resolvedHost = host.isEmpty ? 'localhost' : host;
      return 'http://$resolvedHost:$_defaultPort';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _forceAndroidEmulator ? _androidEmulatorBaseUrl : _physicalAndroidFallbackBaseUrl;
    }

    return _desktopBaseUrl;
  }

  static bool get isPhysicalAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && !_forceAndroidEmulator;

  static bool get requiresPhysicalAndroidBaseUrl => isPhysicalAndroid && !_hasEnvBaseUrl;

  static String get platformLabel {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _forceAndroidEmulator ? 'android-emulator' : 'android';
    }
    return defaultTargetPlatform.name;
  }

  static String _trimTrailingSlash(String value) => value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static const String health = '/health';
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String resendVerification = '/api/auth/resend-verification';
  static const String verifyEmail = '/api/auth/verify-email';
  static const String coupleCreate = '/api/couples/create';
  static const String coupleJoin = '/api/couples/join';
  static const String coupleMe = '/api/couples/me';
  static const String coupleReset = '/api/couples/reset';
  static const String coupleLeave = '/api/couples/leave';
  static const String coupleFilterState = '/api/couples/filter-state';
  static const String coupleFilterStateMe = '/api/couples/filter-state/me';
  static const String coupleFilterStateConfirm = '/api/couples/filter-state/confirm';
  static const String coupleFilterStateReset = '/api/couples/filter-state/reset';
  static const String coupleDeckPrepare = '/api/couples/deck/prepare';
  static const String coupleDeck = '/api/couples/deck';
  static const String coupleDeckReset = '/api/couples/deck/reset';
  static const String dishes = '/api/dishes';
  static const String dishesCatalog = '/api/dishes?limit=all';
  static const String dishesCustom = '/api/dishes/custom';
  static const String dishesMy = '/api/dishes/my';
  static const String swipes = '/api/swipes';
  static const String soloSwipesActive = '/api/solo-swipes/active';
  static const String soloSwipesSession = '/api/solo-swipes/session';
  static const String soloSwipesAbandon = '/api/solo-swipes/active/abandon';
  static const String soloSwipesActiveFilter = '/api/solo-swipes/active/filter';
  static String soloSwipeDeck(String sessionId) => '/api/solo-swipes/$sessionId/deck';
  static String soloSwipe(String sessionId) => '/api/solo-swipes/$sessionId/swipe';
  static const String filtersLast = '/api/filters/last';
  static const String swipeStats = '/api/swipes/me/stats';
  static const String swipeMatches = '/api/swipes/matches';
  static const String recipes = '/api/recipes';
  static const String uploads = '/api/uploads';
  static const String uploadAvatar = '/api/uploads/avatar';
  static const String uploadCustomDishImage = '/api/uploads/custom-dish-image';
  static const String ingredientsSearch = '/api/ingredients/search';
  static const String usersSavedDishes = '/api/users/saved-dishes';
}
