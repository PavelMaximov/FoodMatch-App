import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required ApiService apiService,
    CacheService? cacheService,
  })  : _repository = repository,
        _apiService = apiService,
        _cacheService = cacheService ?? CacheService() {
    _apiService.onUnauthorized = handleSessionExpired;
  }

  final AuthRepository _repository;
  final ApiService _apiService;
  final CacheService _cacheService;

  User? currentUser;
  String? token;
  DateTime? _currentUserLoadedAt;
  Future<void>? _loadUserFuture;
  bool isLoading = false;
  String? error;

  bool requireEmailVerification = false;

  bool get isAuthenticated => token != null;
  bool get needsEmailVerification => requireEmailVerification && currentUser?.emailVerified == false;

  bool get _hasFreshCurrentUser {
    final DateTime? loadedAt = _currentUserLoadedAt;
    return currentUser != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.authUserTtl;
  }

  Future<void> register(String email, String password, String displayName) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.register(email, password, displayName);
      token = response.effectiveAccessToken;
      requireEmailVerification = response.requireEmailVerification;
      _apiService.setToken(response.effectiveAccessToken);
      _apiService.setRefreshToken(response.refreshToken);
      currentUser = response.user ?? await _repository.getMe();
      _currentUserLoadedAt = DateTime.now();
      await _apiService.saveAccessToken(response.effectiveAccessToken);
      if (response.refreshToken != null) {
        await _apiService.saveRefreshToken(response.refreshToken!);
      }
      await _cacheUserDataIfAvailable();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.login(email, password);
      token = response.effectiveAccessToken;
      requireEmailVerification = response.requireEmailVerification;
      _apiService.setToken(response.effectiveAccessToken);
      _apiService.setRefreshToken(response.refreshToken);
      currentUser = response.user ?? await _repository.getMe();
      _currentUserLoadedAt = DateTime.now();
      await _apiService.saveAccessToken(response.effectiveAccessToken);
      if (response.refreshToken != null) {
        await _apiService.saveRefreshToken(response.refreshToken!);
      }
      await _cacheUserDataIfAvailable();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUser({bool force = false}) {
    if (!force && _hasFreshCurrentUser) {
      final int age = DateTime.now().difference(_currentUserLoadedAt!).inSeconds;
      AppLogger.info('[Cache] auth user hit age=${age}s');
      return Future<void>.value();
    }
    final Future<void>? inFlight = _loadUserFuture;
    if (inFlight != null) {
      AppLogger.info('[RequestDedup] auth user refresh skipped: already in flight');
      return inFlight;
    }

    _loadUserFuture = _loadUserFromApi(force: force);
    return _loadUserFuture!;
  }

  Future<void> _loadUserFromApi({required bool force}) async {
    AppLogger.info(force ? '[Cache] auth user force refresh' : '[Cache] auth user miss');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _apiService.loadToken();
      final String? loadedToken = _apiService.token;

      if (loadedToken == null || loadedToken.isEmpty) {
        token = null;
        currentUser = null;
        _currentUserLoadedAt = null;
        return;
      }

      if (_isTokenExpired(loadedToken)) {
        final bool refreshed = await _apiService.refreshTokens();
        if (!refreshed) {
          await handleSessionExpired();
          return;
        }
      }

      token = await _apiService.getAccessToken();
      final me = await _repository.getMeWithVerificationRequirement();
      currentUser = me.user;
      requireEmailVerification = me.requireEmailVerification;
      _currentUserLoadedAt = DateTime.now();
      await _cacheUserDataIfAvailable();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.info('Token invalid (401), clearing session');
        await handleSessionExpired();
      } else {
        error = _mapError(e);
      }
    } catch (e) {
      AppLogger.error('loadUser failed', e);
      error = _mapError(e);
    } finally {
      isLoading = false;
      _loadUserFuture = null;
      notifyListeners();
    }
  }

  bool _isTokenExpired(String token) {
    try {
      final List<String> parts = token.split('.');
      if (parts.length != 3) return true;

      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final String decoded = utf8.decode(base64Url.decode(payload));
      final Map<String, dynamic> map = jsonDecode(decoded) as Map<String, dynamic>;
      final int? exp = map['exp'] as int?;

      if (exp == null) return true;

      final DateTime expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expDate.subtract(const Duration(minutes: 5)));
    } catch (_) {
      return true;
    }
  }

  @visibleForTesting
  bool isTokenExpiredForTest(String inputToken) => _isTokenExpired(inputToken);

  Future<void> handleSessionExpired() async {
    if (!isAuthenticated && currentUser == null) return;
    AppLogger.info('[Auth] session expired cleanup started');
    await _clearAuthState();
    error = ErrorMessages.sessionExpired;
    notifyListeners();
  }

  Future<void> logout() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final String? refreshToken = await _apiService.getRefreshToken();
      await _repository.logout(refreshToken: refreshToken);
      await _clearAuthState();
      AppLogger.info('[Auth] logout cleanup complete');
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }


  Future<void> _clearAuthState() async {
    await _apiService.clearTokens();
    token = null;
    currentUser = null;
    _currentUserLoadedAt = null;
    _loadUserFuture = null;
    _apiService.setToken(null);
    _apiService.setRefreshToken(null);
    requireEmailVerification = false;
    await _cacheService.clearAll();
  }

  Future<void> updateCurrentUserAvatar({
    required String avatarUrl,
    String? avatarPublicId,
  }) async {
    final User? user = currentUser;
    if (user == null) {
      return;
    }

    currentUser = user.copyWith(
      avatarUrl: avatarUrl,
      avatarPublicId: avatarPublicId,
    );
    _currentUserLoadedAt = DateTime.now();
    await _cacheUserDataIfAvailable();
    notifyListeners();
  }

  Future<void> clearCurrentUserAvatar() async {
    final User? user = currentUser;
    if (user == null) {
      return;
    }

    currentUser = user.copyWith(clearAvatar: true);
    _currentUserLoadedAt = DateTime.now();
    await _cacheUserDataIfAvailable();
    notifyListeners();
  }

  Future<void> _cacheUserDataIfAvailable() async {
    if (currentUser == null) {
      return;
    }

    await _cacheService.cacheUserData(
      displayName: currentUser!.displayName,
      email: currentUser!.email,
      coupleId: currentUser!.coupleId,
    );
  }

  Future<void> resendVerification() async {
    await _repository.resendVerification();
  }

  Future<void> checkVerificationStatus() async {
    final me = await _repository.getMeWithVerificationRequirement();
    currentUser = me.user;
    requireEmailVerification = me.requireEmailVerification;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}
