import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/api_constants.dart';
import '../../core/async/single_flight.dart';
import '../../core/config/backend_api_config.dart';
import '../../core/constants/app_strings.dart';
import '../../core/security/certificate_pinning_http_client.dart';
import '../../core/utils/logger.dart';

class ApiService {
  ApiService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
    SupabaseClient? supabaseClient,
    String? Function()? accessTokenProvider,
  }) : _client = client ?? CertificatePinningHttpClient.create(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _supabase = supabaseClient,
       _accessTokenProvider = accessTokenProvider;

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final SupabaseClient? _supabase;
  final String? Function()? _accessTokenProvider;
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 1;
  static const Duration _minRequestInterval = Duration(milliseconds: 300);
  static bool _didLogApiConfig = false;

  bool _isSocketException(Object error) =>
      error.runtimeType.toString() == 'SocketException';

  String? _token;
  final _tokenRefresh = SingleFlight<bool>();
  DateTime? _lastRequestTime;
  Future<void> Function()? onUnauthorized;
  bool _handlingUnauthorized = false;
  int _authBoundaryVersion = 0;

  void invalidateAuthRequests() {
    _authBoundaryVersion++;
    _tokenRefresh.invalidate();
  }

  void Function() _captureRequestScope() {
    final version = _authBoundaryVersion;
    final userId = _supabase?.auth.currentUser?.id;
    final accessToken = _currentAccessToken;
    return () {
      final sameIdentity = userId != null
          ? _supabase?.auth.currentUser?.id == userId
          : _currentAccessToken == accessToken;
      if (version != _authBoundaryVersion || !sameIdentity) {
        throw const ApiException('Account changed. Please try again.', code: 'REQUEST_SCOPE_CHANGED');
      }
    };
  }

  String? get token => _token;

  void _logApiConfigOnce() {
    if (_didLogApiConfig) return;
    _didLogApiConfig = true;
    if (ApiConstants.requiresPhysicalAndroidBaseUrl) {
      AppLogger.info(
        '[ApiConfig] Physical Android device requires API_BASE_URL with your PC LAN IP. Example: --dart-define=API_BASE_URL=http://192.168.x.x:4000',
      );
    }
    AppLogger.info(
      '[ApiConfig] platform=${ApiConstants.platformLabel} physicalDevice=${ApiConstants.isPhysicalAndroid} baseUrl=${ApiConstants.baseUrl}',
    );
  }

  static const String _tokenKey = 'foodmatch_token';
  static const String _accessTokenKey = 'foodmatch_access_token';
  static const String _refreshTokenKey = 'foodmatch_refresh_token';

  Future<void> loadToken() async {
    _token = _currentAccessToken;
    // Remove credentials written by the retired custom JWT implementation.
    await clearLegacyTokens();
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<String?> getAccessToken() async => _currentAccessToken;
  Future<void> clearTokens() async {
    _token = null;
    await clearLegacyTokens();
  }

  Future<void> clearLegacyTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<void> _throttle() async {
    if (_lastRequestTime != null) {
      final Duration elapsed = DateTime.now().difference(_lastRequestTime!);
      if (elapsed < _minRequestInterval) {
        await Future<void>.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<dynamic> get(String endpoint) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('GET', endpoint);
    try {
      await _throttle();
      AppLogger.api('GET', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.get(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope)),
      );
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () => _client.get(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope)),
      );
      stopwatch.stop();
      AppLogger.api(
        'GET',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      AppLogger.error('GET request failed', e);
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('POST', endpoint);
    try {
      await _throttle();
      AppLogger.api('POST', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.post(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () => _client.post(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      stopwatch.stop();
      AppLogger.api(
        'POST',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      if (kIsWeb && e is http.ClientException) {
        AppLogger.error(
          'Network request failed. Check API_BASE_URL, backend status, and CORS.',
          e,
        );
        throw const ApiException(
          'Could not connect to the server. Please try again.',
        );
      }
      AppLogger.error('POST request failed', e);
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('PUT', endpoint);
    try {
      await _throttle();
      AppLogger.api('PUT', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.put(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () => _client.put(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      stopwatch.stop();
      AppLogger.api(
        'PUT',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      AppLogger.error('PUT request failed', e);
      rethrow;
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('PATCH', endpoint);
    try {
      await _throttle();
      AppLogger.api('PATCH', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () =>
            _client.patch(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () =>
            _client.patch(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope), body: jsonEncode(body)),
      );
      stopwatch.stop();
      AppLogger.api(
        'PATCH',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      AppLogger.error('PATCH request failed', e);
      rethrow;
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('DELETE', endpoint);
    try {
      await _throttle();
      AppLogger.api('DELETE', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.delete(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope)),
      );
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () => _client.delete(uri, headers: _getHeaders(assertCurrentScope: assertCurrentScope)),
      );
      stopwatch.stop();
      AppLogger.api(
        'DELETE',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      AppLogger.error('DELETE request failed', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    required String endpoint,
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
  }) async {
    final assertCurrentScope = _captureRequestScope();
    final uri = _backendUri('POST', endpoint);
    try {
      await _throttle();
      AppLogger.api('POST-MULTIPART', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(() async {
        final headers = _getHeaders(withAuth: true, assertCurrentScope: assertCurrentScope)..remove('Content-Type');
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(headers)
          ..fields.addAll(fields ?? const <String, String>{})
          ..files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              file.path,
              contentType: _mediaTypeForFile(file),
            ),
          );

        assertCurrentScope();
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      });
      response = await _refreshAndRetryIfUnauthorized(
        endpoint,
        response,
        assertCurrentScope,
        () async {
          final headers = _getHeaders(withAuth: true, assertCurrentScope: assertCurrentScope)..remove('Content-Type');
          final request = http.MultipartRequest('POST', uri)
            ..headers.addAll(headers)
            ..fields.addAll(fields ?? const <String, String>{})
            ..files.add(
              await http.MultipartFile.fromPath(
                fieldName,
                file.path,
                contentType: _mediaTypeForFile(file),
              ),
            );
          assertCurrentScope();
          final streamed = await _client.send(request);
          return http.Response.fromStream(streamed);
        },
      );

      stopwatch.stop();
      AppLogger.api(
        'POST-MULTIPART',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      assertCurrentScope();
      final dynamic data = _handleResponse(response);
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw const ApiException(AppStrings.unknownError);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      AppLogger.error('POST multipart request failed', e);
      rethrow;
    }
  }

  Future<dynamic> postMultipart(String endpoint, File file) {
    return uploadFile(endpoint: endpoint, file: file);
  }

  MediaType _mediaTypeForFile(File file) {
    final String lowerPath = file.path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lowerPath.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  Map<String, String> _getHeaders({bool withAuth = true, void Function()? assertCurrentScope}) {
    assertCurrentScope?.call();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final String? token = _currentAccessToken;
    if (withAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
      AppLogger.info('[ApiClient] attached Supabase bearer token=true');
    }
    return headers;
  }

  Uri _backendUri(String method, String endpoint) {
    final Uri uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (BackendApiConfig.looksLikeSupabase(uri) &&
        endpoint.startsWith('/api')) {
      throw StateError(
        'Backend API misconfigured: /api requests are being sent to Supabase. '
        'Set API_BASE_URL to the FoodMatch backend URL.',
      );
    }
    _logApiConfigOnce();
    AppLogger.info('[ApiClient] request method=$method path=${uri.path}');
    return uri;
  }

  String? get _currentAccessToken =>
      _accessTokenProvider?.call() ??
      _supabase?.auth.currentSession?.accessToken ??
      _token;

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await request().timeout(_timeout);
      } catch (e) {
        if (e is ApiException && e.code == 'REQUEST_SCOPE_CHANGED') rethrow;
        attempt++;
        if (attempt > _maxRetries) rethrow;
        AppLogger.info('Retrying request: attempt $attempt');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  String? _friendlyErrorType(String endpoint, http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    if (response.statusCode == 401) {
      return _isAuthEndpoint(endpoint)
          ? _extractErrorMessage(response)
          : 'session_expired';
    }
    if (response.statusCode == 404) return 'not_found';
    if (response.statusCode == 409) return 'conflict';
    if (response.statusCode == 413) return 'payload_too_large';
    if (response.statusCode >= 500) return 'server_error';
    return 'http_${response.statusCode}';
  }

  Future<http.Response> _refreshAndRetryIfUnauthorized(
    String endpoint,
    http.Response response,
    void Function() assertCurrentScope,
    Future<http.Response> Function() retry,
  ) async {
    assertCurrentScope();
    if (response.statusCode != 401 || _isAuthEndpoint(endpoint)) {
      return response;
    }
    if (_supabase?.auth.currentSession == null) return response;
    final bool refreshed = await refreshTokens();
    assertCurrentScope();
    if (!refreshed) return response;
    AppLogger.info('[AuthRefresh] original request retry started');
    final retryResponse = await retry().timeout(_timeout);
    if (retryResponse.statusCode >= 200 && retryResponse.statusCode < 300) {
      AppLogger.info('[AuthRefresh] original request retry success');
    }
    return retryResponse;
  }

  bool _isAuthEndpoint(String endpoint) {
    return endpoint == ApiConstants.login ||
        endpoint == ApiConstants.register ||
        endpoint == ApiConstants.refresh ||
        endpoint == ApiConstants.logout ||
        endpoint == ApiConstants.resendVerification ||
        endpoint == ApiConstants.verifyEmail;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    final String errorMessage = _extractErrorMessage(response);
    final String? errorCode = _extractErrorCode(response);

    if (response.statusCode == 401) {
      throw ApiException(errorMessage, statusCode: 401, code: errorCode);
    }

    if (response.statusCode == 404) {
      throw ApiException(errorMessage, statusCode: 404, code: errorCode);
    }

    if (response.statusCode == 400) {
      throw ApiException(errorMessage, statusCode: 400, code: errorCode);
    }

    if (response.statusCode == 413) {
      throw ApiException(errorMessage, statusCode: 413, code: errorCode);
    }

    if (response.statusCode == 409) {
      throw ApiException(errorMessage, statusCode: 409, code: errorCode);
    }

    if (response.statusCode == 422) {
      throw ApiException(errorMessage, statusCode: 422, code: errorCode);
    }

    if (response.statusCode >= 500) {
      throw const ApiException(AppStrings.serverError, statusCode: 500);
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      code: errorCode,
    );
  }

  Future<bool> refreshTokens() => _tokenRefresh.run(_performRefresh);

  Future<bool> _performRefresh() async {
    final SupabaseClient? supabase = _supabase;
    if (supabase?.auth.currentSession == null) {
      AppLogger.info('[AuthRefresh] refresh skipped: missing refresh token');
      return false;
    }
    final assertCurrentScope = _captureRequestScope();
    AppLogger.info('[AuthRefresh] refresh started');
    try {
      final AuthResponse response = await supabase!.auth
          .refreshSession()
          .timeout(_timeout);
      assertCurrentScope();
      final Session? session = response.session;
      if (session == null) {
        await clearTokens();
        _notifyUnauthorized();
        return false;
      }
      _token = session.accessToken;
      AppLogger.info('[AuthRefresh] refresh success');
      return true;
    } on AuthException catch (error) {
      assertCurrentScope();
      final int? statusCode = int.tryParse(error.statusCode ?? '');
      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        await clearTokens();
        _notifyUnauthorized();
        return false;
      }
      AppLogger.info('[AuthRefresh] transient failure; session retained');
      rethrow;
    } catch (e) {
      AppLogger.info(
        '[AuthRefresh] transient failure; tokens retained error=$e',
      );
      rethrow;
    }
  }

  void _notifyUnauthorized() {
    if (_handlingUnauthorized) return;
    final Future<void> Function()? handler = onUnauthorized;
    if (handler == null) return;
    _handlingUnauthorized = true;
    Future<void>.microtask(
      handler,
    ).whenComplete(() => _handlingUnauthorized = false);
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return body['message']?.toString() ??
            body['error']?.toString() ??
            AppStrings.unknownError;
      }
      return AppStrings.unknownError;
    } catch (_) {
      return '${AppStrings.error}: ${response.statusCode}';
    }
  }

  String? _extractErrorCode(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final dynamic code = body['code'];
        return code is String && code.trim().isNotEmpty ? code.trim() : null;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'ApiException: $message';
}
