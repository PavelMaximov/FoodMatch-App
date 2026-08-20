import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/repositories/auth_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

void main() {
  late AuthRepository repository;

  setUp(() {
    final MockClient authHttp = MockClient((http.Request request) async {
      final Map<String, dynamic> user = <String, dynamic>{
        'id': 'supabase-user-id',
        'aud': 'authenticated',
        'email': 'qa@example.com',
        'created_at': '2026-08-20T00:00:00Z',
        'email_confirmed_at': '2026-08-20T00:00:00Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{'display_name': 'QA User'},
      };
      return http.Response(
        jsonEncode(<String, dynamic>{
          'access_token': 'supabase-access-token',
          'refresh_token': 'supabase-refresh-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': user,
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final supabase.SupabaseClient supabaseClient = supabase.SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const supabase.AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: supabase.AuthFlowType.implicit,
      ),
      httpClient: authHttp,
    );
    final ApiService apiService = ApiService(
      client: MockClient(
        (http.Request request) async => http.Response(
          jsonEncode(<String, dynamic>{
            'user': <String, dynamic>{
              'id': 'mongo-runtime-id',
              'email': 'qa@example.com',
              'displayName': 'QA User',
              'avatarUrl': null,
              'measurementSystemPreference': 'auto',
            },
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      ),
      accessTokenProvider: () =>
          supabaseClient.auth.currentSession?.accessToken,
    );
    repository = AuthRepository(apiService, supabaseClient: supabaseClient);
  });

  test('login maps Supabase session and backend profile', () async {
    final response = await repository.login('qa@example.com', 'password123');

    expect(response.effectiveAccessToken, 'supabase-access-token');
    expect(response.refreshToken, 'supabase-refresh-token');
    expect(response.user?.id, 'mongo-runtime-id');
    expect(response.user?.displayName, 'QA User');
  });

  test('register sends display name metadata and maps Supabase user', () async {
    final response = await repository.register(
      'qa@example.com',
      'password123',
      'QA User',
    );

    expect(response.user?.id, 'supabase-user-id');
    expect(response.user?.displayName, 'QA User');
    expect(response.effectiveAccessToken, 'supabase-access-token');
  });
}
