import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_storage.dart';
import '../../models/user.dart';

abstract interface class AuthRepository {
  Future<User> register(String username, String password, String nickname);
  Future<User> login(String username, String password);
  Future<StoredSession?> restoreSession();
  Future<void> updateUser(User user);
  Future<void> logout();
}

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client, {SessionStorage? sessionStorage})
    : _sessionStorage = sessionStorage ?? SecureSessionStorage();

  final ApiClient _client;
  final SessionStorage _sessionStorage;
  StoredSession? _currentSession;

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
        final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
        _client.useSession(userId: user.id, accessToken: token);
        await _save(
          StoredSession(user: user, accessToken: token, expiresAt: expiresAt),
        );
        return user;
      }
      // TODO: Remove this legacy UI-session continuity after the secured backend
      // rollout is complete. It never grants authentication on the new backend.
      final user = User.fromJson(json);
      _client.useSession(userId: user.id);
      await _save(StoredSession(user: user));
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

  @override
  Future<StoredSession?> restoreSession() async {
    final session = await _sessionStorage.read();
    if (session == null) return null;
    if (!session.isLegacy &&
        (session.expiresAt == null ||
            !session.expiresAt!.isAfter(DateTime.now()))) {
      await logout();
      throw const AppFailure(AppFailureType.sessionExpired);
    }
    _currentSession = session;
    _client.useSession(
      userId: session.user.id,
      accessToken: session.accessToken,
    );
    return session;
  }

  @override
  Future<void> updateUser(User user) async {
    final session = _currentSession;
    if (session == null) return;
    await _save(
      StoredSession(
        user: user,
        accessToken: session.accessToken,
        expiresAt: session.expiresAt,
      ),
    );
  }

  @override
  Future<void> logout() async {
    _currentSession = null;
    _client.clearSession();
    await _sessionStorage.clear();
  }

  Future<void> _save(StoredSession session) async {
    _currentSession = session;
    await _sessionStorage.write(session);
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
