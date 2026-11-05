import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a failed mutation is not retried with the next account token', () async {
    var token = 'old-token';
    var calls = 0;
    final service = ApiService(
      accessTokenProvider: () => token,
      client: MockClient((request) async {
        calls++;
        token = 'new-token';
        throw http.ClientException('offline');
      }),
    );
    await expectLater(service.post('/api/test', {'name': 'old item'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'REQUEST_SCOPE_CHANGED')));
    expect(calls, 1);
  });

  test('an old unauthorized response cannot log out the next account', () async {
    final response = Completer<http.Response>();
    var unauthorizedCalls = 0;
    final service = ApiService(
      accessTokenProvider: () => 'token',
      client: MockClient((request) => response.future),
    )..onUnauthorized = () async { unauthorizedCalls++; };
    final request = service.get('/api/test');
    final expectation = expectLater(request,
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'REQUEST_SCOPE_CHANGED')));
    await Future<void>.delayed(Duration.zero);
    service.invalidateAuthRequests();
    response.complete(http.Response('{}', 401));
    await expectation;
    expect(unauthorizedCalls, 0);
  });

  test('account switch during throttle prevents sending a pending mutation', () async {
    var token = 'old-token';
    final methods = <String>[];
    final service = ApiService(
      accessTokenProvider: () => token,
      client: MockClient((request) async {
        methods.add(request.method);
        return http.Response('{}', 200);
      }),
    );
    await service.get('/api/test');
    final pending = service.post('/api/test', {});
    token = 'new-token';
    await expectLater(pending,
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'REQUEST_SCOPE_CHANGED')));
    expect(methods, ['GET']);
  });

  test('multipart uploads use the configured authenticated HTTP client', () async {
    final directory = await Directory.systemTemp.createTemp('foodmatch-upload-test');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/avatar.png').writeAsBytes([1, 2, 3]);
    var calls = 0;
    final service = ApiService(
      accessTokenProvider: () => 'token',
      client: MockClient((request) async {
        calls++;
        expect(request.headers['Authorization'], 'Bearer token');
        expect(request.headers['content-type'], startsWith('multipart/form-data;'));
        return http.Response('{"avatarUrl":"https://example.com/avatar.png"}', 200);
      }),
    );
    final result = await service.uploadFile(endpoint: '/api/upload/avatar', file: file);
    expect(result['avatarUrl'], 'https://example.com/avatar.png');
    expect(calls, 1);
  });

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
