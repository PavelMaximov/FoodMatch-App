import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
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

  String? _token;

  Future<void> loadToken() async {
    _token = await _secureStorage.read(key: 'foodmatch_token');
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      AppLogger.api('GET', uri.toString());
      final response = await _requestWithRetry(
        () => _client.get(uri, headers: _getHeaders()),
      );
      AppLogger.api('GET', uri.toString(), statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException('Request timeout');
    } on SocketException {
      throw const ApiException('No internet connection');
    } catch (e) {
      AppLogger.error('GET request failed', e);
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      AppLogger.api('POST', uri.toString(), body: jsonEncode(body));
      final response = await _requestWithRetry(
        () => _client.post(
          uri,
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );
      AppLogger.api('POST', uri.toString(), statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException('Request timeout');
    } on SocketException {
      throw const ApiException('No internet connection');
    } catch (e) {
      AppLogger.error('POST request failed', e);
      rethrow;
    }
  }

  Future<dynamic> postMultipart(String endpoint, File file) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    try {
      AppLogger.api('POST-MULTIPART', uri.toString(), body: file.path);
      final response = await _requestWithRetry(() async {
        final headers = _getHeaders(withAuth: true)..remove('Content-Type');
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(headers)
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      });

      AppLogger.api(
        'POST-MULTIPART',
        uri.toString(),
        statusCode: response.statusCode,
        body: response.body,
      );
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException('Request timeout');
    } on SocketException {
      throw const ApiException('No internet connection');
    } catch (e) {
      AppLogger.error('POST multipart request failed', e);
      rethrow;
    }
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
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      throw ApiException(_extractErrorMessage(response), statusCode: 401);
    }
    if (response.statusCode == 404) {
      throw ApiException(_extractErrorMessage(response), statusCode: 404);
    }
    if (response.statusCode == 400) {
      throw ApiException(_extractErrorMessage(response), statusCode: 400);
    }
    if (response.statusCode >= 500) {
      throw const ApiException('Server error', statusCode: 500);
    }

    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['message'] ?? body['error'] ?? 'Unknown error';
    } catch (_) {
      return 'Error: ${response.statusCode}';
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
