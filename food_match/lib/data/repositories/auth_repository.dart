import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
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
    AppLogger.info('Response data: $data');
    return AuthResponse.fromJson(_extractAuthResponse(data));
  }

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiService.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    AppLogger.info('Response data: $data');
    return AuthResponse.fromJson(_extractAuthResponse(data));
  }

  Future<User> getMe() async {
    final data = await _apiService.get(ApiConstants.me);
    if (data is Map<String, dynamic>) {
      return User.fromJson(data['user'] as Map<String, dynamic>);
    }
    throw const FormatException('Unexpected auth me response format.');
  }

  Map<String, dynamic> _extractAuthResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final token = data['token'];
      final user = data['user'];
      if (token is String) {
        if (user is Map<String, dynamic>) {
          return <String, dynamic>{'token': token, 'user': user};
        }
        return <String, dynamic>{'token': token};
      }
    }
    throw const FormatException('Unexpected auth response format.');
  }
}
