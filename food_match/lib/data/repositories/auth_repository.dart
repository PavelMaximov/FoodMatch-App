import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/measurement_system.dart';
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthRepository {
  AuthRepository(this._apiService, {supabase.SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? supabase.Supabase.instance.client;

  final ApiService _apiService;
  final supabase.SupabaseClient _supabase;

  supabase.Session? get currentSession => _supabase.auth.currentSession;
  supabase.User? get currentAuthUser => _supabase.auth.currentUser;
  Stream<supabase.AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  Future<AuthResponse> register(
    String email,
    String password,
    String displayName,
  ) async {
    final supabase.AuthResponse response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: <String, dynamic>{'display_name': displayName.trim()},
    );
    AppLogger.info(
      '[Auth] register success user=${response.user?.id ?? 'none'}',
    );
    return _toAuthResponse(response, fallbackDisplayName: displayName.trim());
  }

  Future<AuthResponse> login(String email, String password) async {
    final supabase.AuthResponse response = await _supabase.auth
        .signInWithPassword(email: email.trim(), password: password);
    final User profile = await getMe();
    AppLogger.info('[Auth] login success user=${response.user?.id ?? 'none'}');
    return _toAuthResponse(response, profile: profile);
  }

  Future<User> getMe() async {
    final result = await getMeWithVerificationRequirement();
    return result.user;
  }

  Future<User> updateMeasurementSystemPreference(
    MeasurementSystemPreference preference,
  ) async {
    final data = await _apiService.patch(ApiConstants.preferences, {
      'measurementSystemPreference': preference.value,
    });
    if (data is Map<String, dynamic> && data['user'] is Map) {
      return User.fromJson(Map<String, dynamic>.from(data['user'] as Map));
    }
    throw const FormatException('Unexpected preferences response format.');
  }

  Future<({User user, bool requireEmailVerification})>
  getMeWithVerificationRequirement() async {
    final data = await _apiService.get(ApiConstants.me);
    if (data is Map<String, dynamic>) {
      return (
        user: User.fromJson(data['user'] as Map<String, dynamic>),
        requireEmailVerification:
            data['requireEmailVerification'] as bool? ?? false,
      );
    }
    throw const FormatException('Unexpected auth me response format.');
  }

  Future<void> logout({String? refreshToken}) async {
    await _supabase.auth.signOut();
  }

  Future<void> resendVerification() async {
    final String? email = currentAuthUser?.email;
    if (email == null) {
      throw const FormatException('Missing authenticated email.');
    }
    await _supabase.auth.resend(type: supabase.OtpType.signup, email: email);
  }

  AuthResponse _toAuthResponse(
    supabase.AuthResponse response, {
    User? profile,
    String? fallbackDisplayName,
  }) {
    final supabase.User? authUser = response.user;
    if (authUser == null) {
      throw const FormatException('Supabase did not return a user.');
    }
    final String email = authUser.email ?? '';
    final String displayName =
        authUser.userMetadata?['display_name']?.toString() ??
        fallbackDisplayName ??
        email.split('@').first;
    final User user =
        profile ??
        User(
          id: authUser.id,
          email: email,
          displayName: displayName,
          avatarUrl: authUser.userMetadata?['avatar_url']?.toString(),
          emailVerified: authUser.emailConfirmedAt != null,
        );
    final String accessToken = response.session?.accessToken ?? '';
    return AuthResponse(
      token: accessToken,
      accessToken: accessToken.isEmpty ? null : accessToken,
      refreshToken: response.session?.refreshToken,
      user: user,
      requireEmailVerification:
          response.session == null && authUser.emailConfirmedAt == null,
    );
  }
}
