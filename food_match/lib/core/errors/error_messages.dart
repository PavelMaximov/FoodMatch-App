import '../../data/services/api_service.dart';
import '../constants/app_strings.dart';

class ErrorMessages {
  static const String timeout = 'Connection is taking too long. Please try again.';
  static const String serverUnavailable = 'Server is not available right now. Please try again later.';
  static const String sessionExpired = 'Your session expired. Please log in again.';
  static const String uploadFailed = 'Couldn’t upload image. Please try another photo.';
  static const String swipeFailed = 'Couldn’t save your swipe. Please try again.';
  static const String alreadySwiped = 'This dish was already swiped in this session.';
  static const String noActiveCouple = 'You’re not connected to a partner yet.';
  static const String noFilteredDishes = 'No dishes found for these filters. Try changing your choices.';
  static const String unexpected = 'Something went wrong. Please try again.';

  static String fromException(Object error, {String? fallback}) {
    if (error is ApiException) {
      return fromApiException(error, fallback: fallback);
    }
    return fallback ?? unexpected;
  }

  static String fromApiException(ApiException error, {String? fallback}) {
    if (error.statusCode == 401) return sessionExpired;
    if (error.statusCode == null) {
      final String message = error.message.toLowerCase();
      if (message.contains('timeout') || message.contains('timed out')) return timeout;
      if (message.contains('internet') || message.contains('socket')) return serverUnavailable;
    }
    if (error.statusCode != null && error.statusCode! >= 500) return serverUnavailable;

    final String raw = error.message.trim();
    final String lower = raw.toLowerCase();
    if (lower.contains('e11000') ||
        lower.contains('mongo') ||
        lower.contains('duplicate key') ||
        lower.contains('duplicate swipe')) {
      return alreadySwiped;
    }
    if (lower.contains('no active session') || lower.contains('active couple')) return noActiveCouple;
    if (lower.contains('filter') && (error.statusCode == 409 || lower.contains('no dishes'))) {
      return noFilteredDishes;
    }
    if (_isTechnical(raw)) return fallback ?? unexpected;
    if (raw.isEmpty || raw == AppStrings.unknownError || raw == AppStrings.unexpectedError) {
      return fallback ?? unexpected;
    }
    return raw;
  }

  static bool _isTechnical(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('apiexception') ||
        lower.contains('mongoerror') ||
        lower.contains('internal server error') ||
        lower.contains('socketexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('type cast') ||
        lower.contains('null check operator');
  }
}
