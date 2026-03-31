import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository repository,
    required FlutterSecureStorage secureStorage,
    required ApiService apiService,
  })  : _repository = repository,
        _secureStorage = secureStorage,
        _apiService = apiService;

  final AuthRepository _repository;
  final FlutterSecureStorage _secureStorage;
  final ApiService _apiService;

  User? currentUser;
  String? token;
  bool isLoading = false;
  String? error;

  bool get isAuthenticated => token != null;

  Future<void> register(String email, String password, String displayName) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _repository.register(email, password, displayName);
      token = response.token;
      _apiService.setToken(response.token);
      currentUser = response.user ?? await _repository.getMe();
      await _secureStorage.write(key: 'foodmatch_token', value: response.token);
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
      token = response.token;
      _apiService.setToken(response.token);
      currentUser = response.user ?? await _repository.getMe();
      await _secureStorage.write(key: 'foodmatch_token', value: response.token);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUser() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _apiService.loadToken();
      final String? loadedToken = _apiService.token;

      if (loadedToken == null || loadedToken.isEmpty) {
        token = null;
        currentUser = null;
        return;
      }

      if (_isTokenExpired(loadedToken)) {
        AppLogger.info('Token expired, logging out');
        await logout();
        return;
      }

      token = loadedToken;
      currentUser = await _repository.getMe();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        AppLogger.info('Token invalid (401), logging out');
        await logout();
      } else {
        error = _mapError(e);
      }
    } catch (e) {
      AppLogger.error('loadUser failed', e);
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Check if the stored token is expired.
  /// JWT format: header.payload.signature.
  /// Payload contains "exp" field (Unix timestamp).
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

  Future<void> logout() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _secureStorage.delete(key: 'foodmatch_token');
      token = null;
      currentUser = null;
      _apiService.setToken(null);
    } catch (e) {
      error = _mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  String _mapError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    return AppStrings.unexpectedError;
  }
}
