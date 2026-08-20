import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/local/cache_service.dart';
import 'package:food_match/data/models/auth_response.dart';
import 'package:food_match/data/models/user.dart';
import 'package:food_match/data/repositories/auth_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
    fakeRepo.loginResponse = const AuthResponse(
      token: 'jwt123',
      refreshToken: 'refresh123',
      user: user,
    );

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

  test(
    'transient profile failure retains an existing Supabase session',
    () async {
      fakeRepo.session = supabase.Session(
        accessToken: 'current-access-token',
        refreshToken: 'current-refresh-token',
        tokenType: 'bearer',
        user: const supabase.User(
          id: 'supabase-user',
          appMetadata: <String, dynamic>{},
          userMetadata: <String, dynamic>{},
          aud: 'authenticated',
          email: 'test@test.com',
          createdAt: '2026-08-20T00:00:00Z',
        ),
      );
      fakeRepo.meError = const ApiException(
        'Backend unavailable',
        statusCode: 500,
      );
      provider.currentUser = const User(
        id: 'runtime-user',
        email: 'test@test.com',
        displayName: 'Test',
      );
      provider.token = 'current-access-token';

      await provider.loadUser(force: true);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.id, 'runtime-user');
    },
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(
        _FakeApiService(),
        supabaseClient: supabase.SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
        ),
      );

  AuthResponse? loginResponse;
  Object? loginError;
  Object? meError;
  supabase.Session? session;

  @override
  supabase.Session? get currentSession => session;

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

  @override
  Future<({User user, bool requireEmailVerification})>
  getMeWithVerificationRequirement() async {
    final Object? failure = meError;
    if (failure != null) throw failure;
    throw StateError('A getMe response was not configured.');
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
  Future<void> clearTokens() async {
    _token = null;
  }

  @override
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async =>
      <String, dynamic>{'success': true};
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
  Future<void> clearAuthBoundaryTransient() async {
    wasCleared = true;
  }
}
