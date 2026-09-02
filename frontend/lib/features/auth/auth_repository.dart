import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/user.dart';

abstract interface class AuthRepository {
  Future<User> register(String username, String password, String nickname);
  Future<User> login(String username, String password);
}

class HttpAuthRepository implements AuthRepository {
  const HttpAuthRepository(this._client);

  final ApiClient _client;

  @override
  Future<User> register(String username, String password, String nickname) =>
      _requestUser(
        () => _client.post('/api/auth/register', {
          'username': username,
          'password': password,
          'nickname': nickname,
        }),
        legacyStatusFallback: _legacyRegisterStatus,
      );

  @override
  Future<User> login(String username, String password) => _requestUser(
    () => _client.post('/api/auth/login', {
      'username': username,
      'password': password,
    }),
    legacyStatusFallback: _legacyLoginStatus,
  );

  Future<User> _requestUser(
    Future<Object?> Function() request, {
    required AppFailureType? Function(int statusCode) legacyStatusFallback,
  }) async {
    try {
      final json = Map<String, dynamic>.from((await request())! as Map);
      final nestedUser = json['user'];
      if (nestedUser is Map) {
        final token = json['accessToken'];
        if (token is! String || token.isEmpty) {
          throw const AppFailure(AppFailureType.unknown);
        }
        final user = User.fromJson(Map<String, dynamic>.from(nestedUser));
        _client.useSession(userId: user.id, accessToken: token);
        return user;
      }
      // Compatibility with the pre-authentication backend during the rollout window.
      final user = User.fromJson(json);
      _client.useSession(userId: user.id);
      return user;
    } on ApiException catch (error) {
      throw AppFailure.fromApiException(
        error,
        legacyStatusFallback: legacyStatusFallback,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure(AppFailureType.unknown, message: error.toString());
    }
  }

  static AppFailureType? _legacyLoginStatus(int statusCode) =>
      switch (statusCode) {
        400 => AppFailureType.validation,
        401 => AppFailureType.invalidCredentials,
        404 => AppFailureType.notFound,
        _ when statusCode >= 500 => AppFailureType.server,
        _ => null,
      };

  static AppFailureType? _legacyRegisterStatus(int statusCode) =>
      switch (statusCode) {
        400 => AppFailureType.validation,
        404 => AppFailureType.notFound,
        409 => AppFailureType.usernameExists,
        _ when statusCode >= 500 => AppFailureType.server,
        _ => null,
      };
}
