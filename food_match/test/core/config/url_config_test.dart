import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/config/backend_api_config.dart';
import 'package:food_match/core/config/supabase_config.dart';

void main() {
  group('SUPABASE_URL', () {
    test('accepts and normalizes a project root URL', () {
      expect(
        SupabaseConfig.normalizeUrl(' https://xxx.supabase.co/ '),
        'https://xxx.supabase.co',
      );
    });

    for (final String path in <String>['/rest/v1', '/auth/v1']) {
      test('rejects $path', () {
        expect(
          () => SupabaseConfig.normalizeUrl('https://xxx.supabase.co$path'),
          throwsA(
            isA<StateError>().having(
              (StateError error) => error.message,
              'message',
              contains('Do not include /rest/v1, /auth/v1, /api, or any path'),
            ),
          ),
        );
      });
    }
  });

  group('API_BASE_URL', () {
    test('accepts a FoodMatch backend root URL', () {
      expect(
        BackendApiConfig.normalizeBaseUrl('http://192.168.0.39:4000/'),
        'http://192.168.0.39:4000',
      );
    });

    test('rejects Supabase', () {
      expect(
        () => BackendApiConfig.normalizeBaseUrl('https://xxx.supabase.co'),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('must point to the FoodMatch backend, not Supabase'),
          ),
        ),
      );
    });

    test('rejects an /api path', () {
      expect(
        () => BackendApiConfig.normalizeBaseUrl('http://192.168.0.39:4000/api'),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('do not include /api or any path'),
          ),
        ),
      );
    });

    test('rejects the backend bind address', () {
      expect(
        () => BackendApiConfig.normalizeBaseUrl('http://0.0.0.0:4000'),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('backend bind address'),
          ),
        ),
      );
    });
  });
}
