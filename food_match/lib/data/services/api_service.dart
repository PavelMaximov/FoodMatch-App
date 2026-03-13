import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class ApiService {
  ApiService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  static const Duration _timeout = Duration(seconds: 15);

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConstants.baseUrl}$endpoint'),
            headers: await _getHeaders(),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Network error. Please check your connection.');
    } on HttpException {
      throw const ApiException('Server is unavailable.');
    } on FormatException {
      throw const ApiException('Invalid response format.');
    } on TimeoutException {
      throw const ApiException('Request timeout.');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConstants.baseUrl}$endpoint'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Network error. Please check your connection.');
    } on HttpException {
      throw const ApiException('Server is unavailable.');
    } on FormatException {
      throw const ApiException('Invalid response format.');
    } on TimeoutException {
      throw const ApiException('Request timeout.');
    }
  }

  Future<dynamic> postMultipart(String endpoint, File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
      )
        ..headers.addAll(await _getHeaders(includeContentType: false))
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Network error. Please check your connection.');
    } on HttpException {
      throw const ApiException('Server is unavailable.');
    } on FormatException {
      throw const ApiException('Invalid response format.');
    } on TimeoutException {
      throw const ApiException('Request timeout.');
    }
  }

  Future<Map<String, String>> _getHeaders({bool includeContentType = true}) async {
    final token = await _secureStorage.read(key: 'token');
    final headers = <String, String>{};

    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      data = jsonDecode(response.body);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final message = data is Map<String, dynamic> ? data['message'] as String? : null;
    throw ApiException(
      message ?? 'Request failed with status ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException: $message';
}
