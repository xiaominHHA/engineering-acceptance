import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/user.dart';

class StoredSession {
  const StoredSession({required this.user, this.accessToken, this.expiresAt});

  final User user;
  final String? accessToken;
  final DateTime? expiresAt;

  bool get isLegacy => accessToken == null;

  Map<String, Object?> toJson() => {
    'user': user.toJson(),
    'accessToken': accessToken,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    // Legacy sessions preserve UI continuity only during the backend rollout.
    'legacy': isLegacy,
  };

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    if (userJson is! Map) throw const FormatException('Invalid session user');
    final token = json['accessToken'];
    final expiresAt = json['expiresAt'];
    return StoredSession(
      user: User.fromJson(Map<String, dynamic>.from(userJson)),
      accessToken: token is String && token.isNotEmpty ? token : null,
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
  }
}

abstract interface class SessionStorage {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'authenticated_session';
  final FlutterSecureStorage _storage;

  @override
  Future<StoredSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return StoredSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(StoredSession session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _sessionKey);
}
