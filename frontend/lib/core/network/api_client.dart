import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = AppConfig.apiBaseUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;
  String? _accessToken;
  int? _sessionUserId;

  int? get sessionUserId => _sessionUserId;

  Future<Object?> get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<Object?> post(String path, Map<String, Object?> body) => _send(
    () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  Future<Object?> put(String path, Map<String, Object?> body) => _send(
    () => _client.put(_uri(path), headers: _headers, body: jsonEncode(body)),
  );

  Future<Object?> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  void close() {
    if (_ownsClient) _client.close();
  }

  void useSession({required int userId, String? accessToken}) {
    _sessionUserId = userId;
    _accessToken = accessToken;
  }

  void clearSession() {
    _sessionUserId = null;
    _accessToken = null;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken case final token?) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Object?> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _httpException(response);
      }
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on SocketException {
      throw const ApiException.network();
    } on http.ClientException {
      throw const ApiException.network();
    } on TimeoutException {
      throw const ApiException.network();
    }
  }

  ApiException _httpException(http.Response response) {
    String? code;
    String? message;
    Map<String, String> fieldErrors = const {};
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        code = body['code'] as String?;
        message = body['message'] as String?;
        final rawFieldErrors = body['fieldErrors'];
        if (rawFieldErrors is Map) {
          fieldErrors = rawFieldErrors.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        }
      }
    } on FormatException {
      // The transport status remains available when an upstream body is not JSON.
    }
    return ApiException.http(
      statusCode: response.statusCode,
      code: code,
      message: message,
      fieldErrors: fieldErrors,
    );
  }
}
