import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'attaches the current Supabase bearer token to backend requests',
    () async {
      String? authorization;
      final MockClient client = MockClient((http.Request request) async {
        authorization = request.headers['Authorization'];
        return http.Response(
          '{"ok":true}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final ApiService service = ApiService(
        client: client,
        accessTokenProvider: () => 'supabase-access-token',
      );

      await service.get('/api/test');

      expect(authorization, 'Bearer supabase-access-token');
    },
  );
}
