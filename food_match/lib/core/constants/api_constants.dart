class ApiConstants {
  ApiConstants._();

  static String get baseUrl => 'http://192.168.0.39:4000';

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
  static const String swipeStats = '/api/swipes/me/stats';
  static const String swipeMatches = '/api/swipes/matches';
  static const String recipes = '/api/recipes';
  static const String uploads = '/api/uploads';
  static const String uploadAvatar = '/api/uploads/avatar';
  static const String uploadCustomDishImage = '/api/uploads/custom-dish-image';
  static const String ingredientsSearch = '/api/ingredients/search';
  static const String usersSavedDishes = '/api/users/saved-dishes';
}
