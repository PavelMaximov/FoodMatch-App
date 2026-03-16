import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      final storedToken = await _secureStorage.read(key: 'foodmatch_token');
      if (storedToken == null || storedToken.isEmpty) {
        token = null;
        currentUser = null;
        return;
      }

      token = storedToken;
      _apiService.setToken(storedToken);
      currentUser = await _repository.getMe();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        await logout();
      } else {
        error = _mapError(e);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

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
    return 'Unexpected error occurred';
  }
}
