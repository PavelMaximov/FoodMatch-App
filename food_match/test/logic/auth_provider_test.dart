import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/auth_response.dart';
import 'package:food_match/data/models/user.dart';
import 'package:food_match/data/repositories/auth_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'auth_provider_test.mocks.dart';

@GenerateMocks(<Type>[AuthRepository, ApiService, FlutterSecureStorage])
void main() {
  late AuthProvider provider;
  late MockAuthRepository mockRepo;
  late MockApiService mockApi;
  late MockFlutterSecureStorage mockStorage;

  setUp(() {
    mockRepo = MockAuthRepository();
    mockApi = MockApiService();
    mockStorage = MockFlutterSecureStorage();
    provider = AuthProvider(
      repository: mockRepo,
      apiService: mockApi,
      secureStorage: mockStorage,
    );
  });

  test('login successful sets user and token', () async {
    const User user = User(
      id: '1',
      email: 'test@test.com',
      displayName: 'Test',
      coupleId: null,
    );
    const AuthResponse response = AuthResponse(token: 'jwt123', user: user);

    when(mockRepo.login('test@test.com', 'password')).thenAnswer((_) async => response);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockApi.setToken(any)).thenReturn(null);

    await provider.login('test@test.com', 'password');

    expect(provider.isAuthenticated, true);
    expect(provider.currentUser?.email, 'test@test.com');
    expect(provider.error, isNull);
  });

  test('login with error sets error', () async {
    when(mockRepo.login(any, any)).thenThrow(Exception('Invalid credentials'));

    await provider.login('bad@test.com', 'wrong');

    expect(provider.isAuthenticated, false);
    expect(provider.error, isNotNull);
  });

  test('logout clears user and token', () async {
    provider.token = 'jwt';
    provider.currentUser = const User(
      id: '1',
      email: 'test@test.com',
      displayName: 'Test',
      coupleId: null,
    );

    when(mockStorage.delete(key: anyNamed('key'))).thenAnswer((_) async {});
    when(mockApi.setToken(any)).thenReturn(null);

    await provider.logout();

    expect(provider.isAuthenticated, false);
    expect(provider.currentUser, isNull);
  });

  test('expired token detected correctly', () {
    final int pastExp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 60;
    final String header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final String payload = base64Url.encode(utf8.encode('{"exp":$pastExp}'));
    const String signature = 'signature';
    final String token = '$header.$payload.$signature';

    expect(provider.isTokenExpiredForTest(token), isTrue);
  });
}
