import '../../core/constants/api_constants.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthRepository {
  AuthRepository(this._apiService);

  final ApiService _apiService;

  Future<AuthResponse> register(
    String email,
    String password,
    String displayName,
  ) async {
    final data = await _apiService.post(ApiConstants.register, {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    return AuthResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiService.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(Map<String, dynamic>.from(data));
  }

  Future<User> getMe() async {
    final data = await _apiService.get(ApiConstants.me);
    return User.fromJson(Map<String, dynamic>.from(data));
  }
}
