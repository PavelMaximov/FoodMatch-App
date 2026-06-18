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
    return AuthResponse.fromJson(_extractAuthResponse(data));
  }

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiService.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(_extractAuthResponse(data));
  }

  Future<User> getMe() async {
    final result = await getMeWithVerificationRequirement();
    return result.user;
  }

  Future<({User user, bool requireEmailVerification})> getMeWithVerificationRequirement() async {
    final data = await _apiService.get(ApiConstants.me);
    if (data is Map<String, dynamic>) {
      return (
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        requireEmailVerification: data['requireEmailVerification'] as bool? ?? false,
      );
    }
    throw const FormatException('Unexpected auth me response format.');
  }

  Future<void> logout({String? refreshToken}) async {
    try {
      await _apiService.post(ApiConstants.logout, {
        if (refreshToken != null) 'refreshToken': refreshToken,
      });
    } catch (e) {
      AppLogger.info('[Auth] server logout skipped: local cleanup will continue');
    }
  }

  Future<void> resendVerification() async {
    await _apiService.post(ApiConstants.resendVerification, const <String, dynamic>{});
  }

  Map<String, dynamic> _extractAuthResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final token = data['accessToken'] ?? data['token'];
      if (token is String) {
        return <String, dynamic>{...data, 'token': token};
      }
    }
    throw const FormatException('Unexpected auth response format.');
  }
}
