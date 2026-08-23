import '../../core/constants/api_constants.dart';
import '../../core/utils/logger.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/measurement_system.dart';
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

enum RegistrationFailureStage { supabaseSignup, backendProfileResolution }

class RegistrationException implements Exception {
  const RegistrationException({
    required this.stage,
    required this.userMessage,
    this.code,
  });

  final RegistrationFailureStage stage;
  final String userMessage;
  final String? code;

  @override
  String toString() => userMessage;
}

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
    AppLogger.info('[Auth] register start');
    late final supabase.AuthResponse response;
    try {
      response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{'display_name': displayName.trim()},
      );
    } on supabase.AuthException catch (error) {
      AppLogger.info(
        '[Auth] register failed stage=supabase_signup '
        'code=${error.code ?? error.statusCode ?? 'unknown'} message=${error.message}',
      );
      throw RegistrationException(
        stage: RegistrationFailureStage.supabaseSignup,
        userMessage: _signupUserMessage(error),
        code: error.code ?? error.statusCode,
      );
    } catch (error) {
      AppLogger.info(
        '[Auth] register failed stage=supabase_signup '
        'code=unknown message=${error.runtimeType}',
      );
      throw const RegistrationException(
        stage: RegistrationFailureStage.supabaseSignup,
        userMessage: 'Account creation failed. Please try again.',
      );
    }
    AppLogger.info(
      '[Auth] register supabase signup success user=${response.user?.id ?? 'none'}',
    );
    User? profile;
    if (response.session != null) {
      AppLogger.info('[Auth] register profile resolution start');
      try {
        profile = await getMe();
      } on ApiException catch (error) {
        AppLogger.info(
          '[Auth] register profile resolution failed '
          'code=${error.code ?? error.statusCode ?? 'unknown'} message=${error.message}',
        );
        AppLogger.info(
          '[Auth] register failed stage=backend_profile_resolution '
          'code=${error.code ?? error.statusCode ?? 'unknown'} message=${error.message}',
        );
        if (error.code == 'SUPABASE_TOKEN_INVALID') {
          AppLogger.info('[Auth] hint=supabase_project_mismatch');
        }
        throw RegistrationException(
          stage: RegistrationFailureStage.backendProfileResolution,
          userMessage: error.code == 'SUPABASE_TOKEN_INVALID'
              ? 'Account was created, but the backend rejected the Supabase session. Check that the app and backend use the same Supabase project.'
              : 'Account was created, but profile setup failed. Please try logging in again.',
          code: error.code ?? error.statusCode?.toString(),
        );
      } catch (error) {
        AppLogger.info(
          '[Auth] register profile resolution failed '
          'code=unknown message=${error.runtimeType}',
        );
        AppLogger.info(
          '[Auth] register failed stage=backend_profile_resolution '
          'code=unknown message=${error.runtimeType}',
        );
        throw const RegistrationException(
          stage: RegistrationFailureStage.backendProfileResolution,
          userMessage:
              'Account was created, but profile setup failed. Please try logging in again.',
        );
      }
    }
    return _toAuthResponse(
      response,
      profile: profile,
      fallbackDisplayName: displayName.trim(),
    );
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

  String _signupUserMessage(supabase.AuthException error) {
    if (error.message.toLowerCase().contains('invalid path specified')) {
      return 'Supabase authentication is misconfigured. Check SUPABASE_URL and try again.';
    }
    return error.message;
  }
}
