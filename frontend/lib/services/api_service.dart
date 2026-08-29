import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/post.dart';
import '../models/user.dart';

class ApiService {
  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');
  Future<User> register(
    String username,
    String password,
    String nickname,
  ) async {
    final response = await http.post(
      _uri('/api/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'nickname': nickname,
      }),
    );
    return _user(response);
  }

  Future<User> login(String username, String password) async {
    final response = await http.post(
      _uri('/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _user(response);
  }

  Future<User> updateUser(
    User user, {
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) async {
    final response = await http.put(
      _uri('/api/users/${user.id}'),
      headers: _headers,
      body: jsonEncode({
        'nickname': nickname,
        'birthday': birthday,
        'school': school,
        'className': className,
      }),
    );
    return _user(response);
  }

  Future<List<Post>> posts() async {
    final response = await http.get(_uri('/api/posts'));
    _check(response);
    return (jsonDecode(response.body) as List)
        .map((item) => Post.fromJson(item))
        .toList();
  }

  Future<Post> createPost(
    int authorUserId,
    String title,
    String content,
  ) async {
    final response = await http.post(
      _uri('/api/posts'),
      headers: _headers,
      body: jsonEncode({
        'authorUserId': authorUserId,
        'title': title,
        'content': content,
      }),
    );
    _check(response);
    return Post.fromJson(jsonDecode(response.body));
  }

  static const _headers = {'Content-Type': 'application/json'};
  User _user(http.Response response) {
    _check(response);
    return User.fromJson(jsonDecode(response.body));
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed');
    }
  }
}
