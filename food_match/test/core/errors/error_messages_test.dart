import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/errors/error_messages.dart';
import 'package:food_match/data/services/api_service.dart';

void main() {
  test('maps missing Supabase profile to a recoverable setup message', () {
    const error = ApiException(
      'User profile is not ready',
      statusCode: 500,
      code: 'SUPABASE_PROFILE_MISSING',
    );

    expect(
      ErrorMessages.fromApiException(error),
      'Your profile is not ready yet. Please try again.',
    );
  });
}
