import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/security/certificate_pinning_http_client.dart';
import '../../core/utils/logger.dart';

class ApiService {
  ApiService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? CertificatePinningHttpClient.create(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 1;
  static const Duration _minRequestInterval = Duration(milliseconds: 300);
  static bool _didLogApiConfig = false;

  bool _isSocketException(Object error) => error.runtimeType.toString() == 'SocketException';

  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshFuture;
  DateTime? _lastRequestTime;
  Future<void> Function()? onUnauthorized;
  bool _handlingUnauthorized = false;

  String? get token => _token;

  void _logApiConfigOnce() {
    if (_didLogApiConfig) return;
    _didLogApiConfig = true;
    if (ApiConstants.requiresPhysicalAndroidBaseUrl) {
      AppLogger.info('[ApiConfig] Physical Android device requires API_BASE_URL with your PC LAN IP. Example: --dart-define=API_BASE_URL=http://192.168.x.x:4000');
    }
    AppLogger.info('[ApiConfig] platform=${ApiConstants.platformLabel} physicalDevice=${ApiConstants.isPhysicalAndroid} baseUrl=${ApiConstants.baseUrl}');
  }

  static const String _tokenKey = 'foodmatch_token';
  static const String _accessTokenKey = 'foodmatch_access_token';
  static const String _refreshTokenKey = 'foodmatch_refresh_token';

  Future<void> loadToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? legacyToken = prefs.getString(_tokenKey);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _tokenKey, value: legacyToken);
      await prefs.remove(_tokenKey);
    }
    _token = await _secureStorage.read(key: _accessTokenKey) ?? await _secureStorage.read(key: _tokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (_token != null) {
      await _secureStorage.write(key: _accessTokenKey, value: _token);
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  void setToken(String? token) { _token = token; }
  void setRefreshToken(String? refreshToken) { _refreshToken = refreshToken; }
  Future<void> saveAccessToken(String token) async {
    _token = token;
    await _secureStorage.write(key: _accessTokenKey, value: token);
    await _secureStorage.delete(key: _tokenKey);
  }
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }
  Future<void> saveTokenPair({required String accessToken, required String refreshToken}) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    await _secureStorage.delete(key: _tokenKey);
  }
  Future<String?> getAccessToken() async => _token ?? _secureStorage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() async => _refreshToken ?? _secureStorage.read(key: _refreshTokenKey);
  Future<void> clearTokens() async { _token = null; _refreshToken = null; await _secureStorage.delete(key: _accessTokenKey); await _secureStorage.delete(key: _refreshTokenKey); await _secureStorage.delete(key: _tokenKey); }

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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      _logApiConfigOnce();
      _logApiConfigOnce();
      await _throttle();
      AppLogger.api('GET', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.get(uri, headers: _getHeaders()),
      );
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () => _client.get(uri, headers: _getHeaders()));
      stopwatch.stop();
      AppLogger.api(
        'GET',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('POST', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.post(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () => _client.post(uri, headers: _getHeaders(), body: jsonEncode(body)));
      stopwatch.stop();
      AppLogger.api(
        'POST',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } catch (e) {
      if (_isSocketException(e)) {
        throw const ApiException(AppStrings.noInternet);
      }
      if (kIsWeb && e is http.ClientException) {
        AppLogger.error('Network request failed. Check API_BASE_URL, backend status, and CORS.', e);
        throw const ApiException('Could not connect to the server. Please try again.');
      }
      AppLogger.error('POST request failed', e);
      rethrow;
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('PUT', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.put(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () => _client.put(uri, headers: _getHeaders(), body: jsonEncode(body)));
      stopwatch.stop();
      AppLogger.api(
        'PUT',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('PATCH', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.patch(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () => _client.patch(uri, headers: _getHeaders(), body: jsonEncode(body)));
      stopwatch.stop();
      AppLogger.api(
        'PATCH',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('DELETE', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(
        () => _client.delete(uri, headers: _getHeaders()),
      );
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () => _client.delete(uri, headers: _getHeaders()));
      stopwatch.stop();
      AppLogger.api(
        'DELETE',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('POST-MULTIPART', uri.toString());
      final stopwatch = Stopwatch()..start();
      var response = await _requestWithRetry(() async {
        final headers = _getHeaders(withAuth: true)..remove('Content-Type');
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

        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      });
      response = await _refreshAndRetryIfUnauthorized(endpoint, response, () async {
        final headers = _getHeaders(withAuth: true)..remove('Content-Type');
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
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      });

      stopwatch.stop();
      AppLogger.api(
        'POST-MULTIPART',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(endpoint, response),
      );
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

  Map<String, String> _getHeaders({bool withAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _token;
    if (withAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        return await request().timeout(_timeout);
      } catch (e) {
        attempt++;
        if (attempt > _maxRetries) rethrow;
        AppLogger.info('Retrying request: attempt $attempt');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  String? _friendlyErrorType(String endpoint, http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    if (response.statusCode == 401) return _isAuthEndpoint(endpoint) ? _extractErrorMessage(response) : 'session_expired';
    if (response.statusCode == 404) return 'not_found';
    if (response.statusCode == 409) return 'conflict';
    if (response.statusCode == 413) return 'payload_too_large';
    if (response.statusCode >= 500) return 'server_error';
    return 'http_${response.statusCode}';
  }


  Future<http.Response> _refreshAndRetryIfUnauthorized(
    String endpoint,
    http.Response response,
    Future<http.Response> Function() retry,
  ) async {
    if (response.statusCode != 401 || _isAuthEndpoint(endpoint)) {
      return response;
    }
    final String? refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return response;
    final bool refreshed = await refreshTokens();
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

    throw ApiException(errorMessage, statusCode: response.statusCode, code: errorCode);
  }

  Future<bool> refreshTokens() {
    final Future<bool>? inFlight = _refreshFuture;
    if (inFlight != null) {
      AppLogger.info('[RequestDedup] refresh reused existing request');
      return inFlight;
    }
    _refreshFuture = _performRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<bool> _performRefresh() async {
    final String? refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      AppLogger.info('[AuthRefresh] refresh skipped: missing refresh token');
      return false;
    }
    AppLogger.info('[AuthRefresh] refresh started');
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}');
      AppLogger.info('[AuthRefresh] refresh request sent');
      final response = await _client.post(uri, headers: _getHeaders(withAuth: false), body: jsonEncode({'refreshToken': refreshToken})).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.info('[AuthRefresh] refresh failed status=${response.statusCode} message=${_extractErrorMessage(response)}');
        if (response.statusCode == 401 || response.statusCode == 403) {
          await clearTokens();
          _notifyUnauthorized();
          return false;
        }
        throw ApiException(
          _extractErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = (data['accessToken'] ?? data['token']) as String?;
      final newRefreshToken = data['refreshToken'] as String?;
      if (accessToken == null || newRefreshToken == null) throw const FormatException('Missing refreshed token pair');
      await saveTokenPair(accessToken: accessToken, refreshToken: newRefreshToken);
      AppLogger.info('[AuthRefresh] refresh success');
      return true;
    } catch (e) {
      AppLogger.info('[AuthRefresh] transient failure; tokens retained error=$e');
      rethrow;
    }
  }

  void _notifyUnauthorized() {
    if (_handlingUnauthorized) return;
    final Future<void> Function()? handler = onUnauthorized;
    if (handler == null) return;
    _handlingUnauthorized = true;
    Future<void>.microtask(handler).whenComplete(() => _handlingUnauthorized = false);
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
