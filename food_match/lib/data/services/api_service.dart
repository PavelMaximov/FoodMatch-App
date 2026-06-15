import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/logger.dart';

class ApiService {
  ApiService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxRetries = 1;
  static const Duration _minRequestInterval = Duration(milliseconds: 300);

  String? _token;
  DateTime? _lastRequestTime;
  Future<void> Function()? onUnauthorized;
  bool _handlingUnauthorized = false;

  String? get token => _token;

  Future<void> loadToken() async {
    _token = await _secureStorage.read(key: 'foodmatch_token');
  }

  void setToken(String? token) {
    _token = token;
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
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('GET', uri.toString());
      final stopwatch = Stopwatch()..start();
      final response = await _requestWithRetry(
        () => _client.get(uri, headers: _getHeaders()),
      );
      stopwatch.stop();
      AppLogger.api(
        'GET',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(response),
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } on SocketException {
      throw const ApiException(AppStrings.noInternet);
    } catch (e) {
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
      final response = await _requestWithRetry(
        () => _client.post(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      stopwatch.stop();
      AppLogger.api(
        'POST',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(response),
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } on SocketException {
      throw const ApiException(AppStrings.noInternet);
    } catch (e) {
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
      final response = await _requestWithRetry(
        () => _client.put(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      stopwatch.stop();
      AppLogger.api(
        'PUT',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(response),
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } on SocketException {
      throw const ApiException(AppStrings.noInternet);
    } catch (e) {
      AppLogger.error('PUT request failed', e);
      rethrow;
    }
  }


  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      await _throttle();
      AppLogger.api('DELETE', uri.toString());
      final stopwatch = Stopwatch()..start();
      final response = await _requestWithRetry(
        () => _client.delete(uri, headers: _getHeaders()),
      );
      stopwatch.stop();
      AppLogger.api(
        'DELETE',
        uri.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        errorType: _friendlyErrorType(response),
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } on SocketException {
      throw const ApiException(AppStrings.noInternet);
    } catch (e) {
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
      final response = await _requestWithRetry(() async {
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
        errorType: _friendlyErrorType(response),
      );
      final dynamic data = _handleResponse(response);
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw const ApiException(AppStrings.unknownError);
    } on TimeoutException {
      throw const ApiException(AppStrings.requestTimeout);
    } on SocketException {
      throw const ApiException(AppStrings.noInternet);
    } catch (e) {
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

  String? _friendlyErrorType(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    if (response.statusCode == 401) return 'session_expired';
    if (response.statusCode == 404) return 'not_found';
    if (response.statusCode == 409) return 'conflict';
    if (response.statusCode == 413) return 'payload_too_large';
    if (response.statusCode >= 500) return 'server_error';
    return 'http_${response.statusCode}';
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    final String errorMessage = _extractErrorMessage(response);

    if (response.statusCode == 401) {
      _token = null;
      _notifyUnauthorized();
      throw const ApiException('Your session expired. Please log in again.', statusCode: 401);
    }

    if (response.statusCode == 404) {
      throw ApiException(errorMessage, statusCode: 404);
    }

    if (response.statusCode == 400) {
      throw ApiException(errorMessage, statusCode: 400);
    }

    if (response.statusCode == 413) {
      throw ApiException(errorMessage, statusCode: 413);
    }

    if (response.statusCode == 409) {
      throw ApiException(errorMessage, statusCode: 409);
    }

    if (response.statusCode == 422) {
      throw ApiException(errorMessage, statusCode: 422);
    }

    if (response.statusCode >= 500) {
      throw const ApiException(AppStrings.serverError, statusCode: 500);
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
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
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}
