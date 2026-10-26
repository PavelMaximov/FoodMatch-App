import 'dart:async';

import '../../../core/async/single_flight.dart';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/cache_policy.dart';
import '../../../data/local/cache_service.dart';
import '../../../data/models/user.dart';
import '../../../data/models/measurement_system.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required ApiService apiService,
    CacheService? cacheService,
  }) : _repository = repository,
       _apiService = apiService,
       _cacheService = cacheService ?? CacheService() {
    _apiService.onUnauthorized = handleSessionExpired;
    _authSubscription = _repository.onAuthStateChange.listen(
      _handleAuthStateChange,
    );
  }

  final AuthRepository _repository;
  final ApiService _apiService;
  final CacheService _cacheService;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  User? currentUser;
  String? token;
  DateTime? _currentUserLoadedAt;
  final _userLoad = SingleFlight<void>();
  bool _disposed = false;
  bool _isClearingAuth = false;
  bool isLoading = false;
  bool profileSetupReady = true;
  String? error;
  int authBoundaryVersion = 0;

  bool requireEmailVerification = false;

  bool get isAuthenticated => token != null || needsEmailVerification;
  bool get needsEmailVerification =>
      requireEmailVerification && currentUser?.emailVerified == false;
  MeasurementSystemPreference get measurementSystemPreference =>
      currentUser?.measurementSystemPreference ??
      MeasurementSystemPreference.auto;

  Future<bool> updateMeasurementSystemPreference(
    MeasurementSystemPreference preference,
  ) async {
    final version = authBoundaryVersion;
    try {
      final updated = await _repository.updateMeasurementSystemPreference(
        preference,
      );
      if (_disposed || version != authBoundaryVersion) return false;
      currentUser = updated;
      _currentUserLoadedAt = DateTime.now();
      await _cacheUserDataIfAvailable();
      notifyListeners();
      return true;
    } catch (exception) {
      AppLogger.error('Measurement preference update failed', exception);
      return false;
    }
  }

  bool get _hasFreshCurrentUser {
    final DateTime? loadedAt = _currentUserLoadedAt;
    return currentUser != null &&
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < CachePolicy.authUserTtl;
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    _userLoad.invalidate();
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.register(email, password, displayName);
      token =
          _repository.currentSession?.accessToken ??
          (response.effectiveAccessToken.isEmpty
              ? null
              : response.effectiveAccessToken);
      _apiService.setToken(token);
      requireEmailVerification = response.requireEmailVerification;
      currentUser = response.user;
      _markAuthBoundaryChanged(reason: 'register');
      _currentUserLoadedAt = DateTime.now();
      await _cacheUserDataIfAvailable();
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _userLoad.invalidate();
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.login(email, password);
      token =
          _repository.currentSession?.accessToken ??
          response.accessToken ??
          response.effectiveAccessToken;
      _apiService.setToken(token);
      requireEmailVerification = response.requireEmailVerification;
      currentUser = response.user ?? await _repository.getMe();
      _markAuthBoundaryChanged(reason: 'login');
      _currentUserLoadedAt = DateTime.now();
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
      final int age = DateTime.now()
          .difference(_currentUserLoadedAt!)
          .inSeconds;
      AppLogger.info('[Cache] auth user hit age=${age}s');
      return Future<void>.value();
    }
    if (_disposed || _isClearingAuth) return Future<void>.value();
    return _userLoad.run(() => _loadUserFromApi(force: force));
  }

  Future<void> _loadUserFromApi({required bool force}) async {
    final generation = _userLoad.generation;
    bool isCurrent() => !_disposed && _userLoad.isCurrent(generation);
    AppLogger.info(
      force ? '[Cache] auth user force refresh' : '[Cache] auth user miss',
    );
    isLoading = true;
    error = null;
    notifyListeners();
    if (!isCurrent()) return;

    try {
      final supabase.Session? session = _repository.currentSession;
      AppLogger.info('[Auth] restore session found=${session != null}');
      if (session == null) {
        if (currentUser != null || token != null) {
          await _clearAuthState();
          if (!_disposed) notifyListeners();
        }
        return;
      }
      token = session.accessToken;
      _apiService.setToken(token);
      final String? previousUserId = currentUser?.id;
      final me = await _repository.getMeWithVerificationRequirement();
      if (!isCurrent()) return;
      currentUser = me.user;
      profileSetupReady = true;
      requireEmailVerification = me.requireEmailVerification;
      if (previousUserId != currentUser?.id) {
        _markAuthBoundaryChanged(reason: 'loadUser');
      }
      _currentUserLoadedAt = DateTime.now();
      await _cacheUserDataIfAvailable();
    } on ApiException catch (e) {
      if (!isCurrent()) return;
      if (e.code == 'SUPABASE_PROFILE_MISSING') {
        profileSetupReady = false;
      }
      if (e.statusCode == 401) {
        AppLogger.info('Token invalid (401), clearing session');
        await handleSessionExpired();
      } else {
        AppLogger.info(
          '[Auth] retained session reason=${e.statusCode != null && e.statusCode! >= 500 ? 'server_error' : 'request_error'}',
        );
        error = _mapError(e);
      }
    } catch (e) {
      if (!isCurrent()) return;
      AppLogger.error('loadUser failed', e);
      AppLogger.info('[Auth] retained session reason=network_error');
      error = _mapError(e);
    } finally {
      if (isCurrent()) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> handleSessionExpired() async {
    if (!isAuthenticated && currentUser == null) return;
    AppLogger.info('[Auth] session expired cleanup started');
    await _clearAuthState();
    error = ErrorMessages.sessionExpired;
    notifyListeners();
  }

  Future<void> logout() async {
    _userLoad.invalidate();
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      AppLogger.info('[Auth] token clear reason=explicit_logout');
      await _notifyPairDisconnectBeforeLogout();
      await _repository.logout();
      await _clearAuthState();
      AppLogger.info('[Auth] logout explicit');
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyPairDisconnectBeforeLogout() async {
    try {
      AppLogger.info('[PairLifecycle] logout -> partner-disconnect requested');
      await _apiService.post(
        ApiConstants.couplePartnerDisconnect,
        <String, dynamic>{},
      );
      AppLogger.info('[PairLifecycle] logout -> partner-disconnect success');
    } catch (e) {
      AppLogger.info('[PairLifecycle] logout -> partner-disconnect failed');
    }
  }

  void _markAuthBoundaryChanged({required String reason}) {
    authBoundaryVersion++;
    AppLogger.info(
      '[Auth] boundary changed reason=$reason version=$authBoundaryVersion',
    );
  }

  Future<void> _clearAuthState() async {
    if (_isClearingAuth) return;
    _isClearingAuth = true;
    _userLoad.invalidate();
    isLoading = false;
    try {
      await _apiService.clearTokens();
      token = null;
      currentUser = null;
      _currentUserLoadedAt = null;
      _apiService.setToken(null);
      requireEmailVerification = false;
      _markAuthBoundaryChanged(reason: 'clearAuthState');
      await _cacheService.clearAuthBoundaryTransient();
    } finally {
      _isClearingAuth = false;
    }
  }

  void _handleAuthStateChange(supabase.AuthState state) {
    if (_disposed) return;
    switch (state.event) {
      case supabase.AuthChangeEvent.tokenRefreshed:
        token = state.session?.accessToken;
        _apiService.setToken(token);
        AppLogger.info('[Auth] token refreshed');
        notifyListeners();
      case supabase.AuthChangeEvent.signedOut:
        if (token != null || currentUser != null) {
          unawaited(
            _clearAuthState().then((_) {
              if (!_disposed) notifyListeners();
            }),
          );
        }
      case supabase.AuthChangeEvent.userUpdated:
        if (state.session != null) unawaited(loadUser(force: true));
      case supabase.AuthChangeEvent.signedIn:
        _userLoad.invalidate();
        token = state.session?.accessToken;
        _apiService.setToken(token);
      default:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _userLoad.invalidate();
    if (_apiService.onUnauthorized == handleSessionExpired) {
      _apiService.onUnauthorized = null;
    }
    _authSubscription?.cancel();
    super.dispose();
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
    final version = authBoundaryVersion;
    final me = await _repository.getMeWithVerificationRequirement();
    if (_disposed || version != authBoundaryVersion) return;
    currentUser = me.user;
    requireEmailVerification = me.requireEmailVerification;
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is RegistrationException) {
      return e.userMessage;
    }
    if (e is supabase.AuthException) {
      final String message = e.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return ErrorMessages.invalidCredentials;
      }
      if (message.contains('already registered') ||
          message.contains('already exists')) {
        return ErrorMessages.emailAlreadyRegistered;
      }
      return e.message;
    }
    if (e is ApiException) {
      return ErrorMessages.fromApiException(e);
    }
    return ErrorMessages.unexpected;
  }
}
