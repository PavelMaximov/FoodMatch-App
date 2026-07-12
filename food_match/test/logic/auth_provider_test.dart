import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/auth_response.dart';
import 'package:food_match/data/models/user.dart';
import 'package:food_match/data/repositories/auth_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';

void main() {
  late AuthProvider provider;
  late _FakeAuthRepository fakeRepo;
  late _FakeApiService fakeApi;
  late _FakeCacheService fakeCacheService;

  setUp(() {
    fakeRepo = _FakeAuthRepository();
    fakeApi = _FakeApiService();
    fakeCacheService = _FakeCacheService();
    provider = AuthProvider(
      repository: fakeRepo,
      apiService: fakeApi,
      cacheService: fakeCacheService,
    );
  });

  test('login successful sets user and token', () async {
    const User user = User(
      id: '1',
      email: 'test@test.com',
      displayName: 'Test',
      coupleId: null,
    );
    fakeRepo.loginResponse = const AuthResponse(token: 'jwt123', refreshToken: 'refresh123', user: user);

    await provider.login('test@test.com', 'password');

    expect(provider.isAuthenticated, true);
    expect(provider.currentUser?.email, 'test@test.com');
    expect(provider.error, isNull);
    expect(fakeApi.token, 'jwt123');
    expect(fakeCacheService.cachedName, 'Test');
  });

  test('login with error sets error', () async {
    fakeRepo.loginError = Exception('Invalid credentials');

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

    await provider.logout();

    expect(provider.isAuthenticated, false);
    expect(provider.currentUser, isNull);
    expect(fakeApi.token, isNull);
    expect(fakeCacheService.wasCleared, isTrue);
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

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(_FakeApiService());

  AuthResponse? loginResponse;
  Object? loginError;

  @override
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<AuthResponse> login(String email, String password) async {
    final Object? error = loginError;
    if (error != null) {
      throw error;
    }
    final AuthResponse? response = loginResponse;
    if (response == null) {
      throw StateError('loginResponse must be set before calling login.');
    }
    return response;
  }
}

class _FakeApiService extends ApiService {
  String? _token;

  @override
  String? get token => _token;

  @override
  void setToken(String? token) {
    _token = token;
  }

  @override
  Future<void> saveTokenPair({required String accessToken, required String refreshToken}) async {
    _token = accessToken;
  }

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> clearTokens() async {
    _token = null;
  }
}

class _FakeCacheService extends CacheService {
  String? cachedName;
  bool wasCleared = false;

  @override
  Future<void> cacheUserData({
    required String displayName,
    required String email,
    String? coupleId,
  }) async {
    cachedName = displayName;
  }

  @override
  Future<void> clearAll() async {
    wasCleared = true;
  }
}
