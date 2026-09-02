import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/user.dart';

abstract interface class UserRepository {
  Future<User> get(int userId);
  Future<User> update(
    int userId, {
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  });
}

class HttpUserRepository implements UserRepository {
  const HttpUserRepository(this._client);

  final ApiClient _client;

  @override
  Future<User> get(int userId) =>
      _requestUser(() => _client.get('/api/users/$userId'));

  @override
  Future<User> update(
    int userId, {
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) async {
    return _requestUser(
      () => _client.put('/api/users/$userId', {
        'nickname': nickname,
        'birthday': birthday,
        'school': school,
        'className': className,
      }),
    );
  }

  Future<User> _requestUser(Future<Object?> Function() request) async {
    try {
      final json = await request();
      return User.fromJson(Map<String, dynamic>.from(json! as Map));
    } on ApiException catch (error) {
      throw AppFailure.fromApiException(
        error,
        legacyStatusFallback: _legacyStatus,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure(AppFailureType.unknown, message: error.toString());
    }
  }

  static AppFailureType? _legacyStatus(int statusCode) => switch (statusCode) {
    400 => AppFailureType.validation,
    401 => AppFailureType.sessionExpired,
    403 => AppFailureType.forbidden,
    404 => AppFailureType.notFound,
    _ when statusCode >= 500 => AppFailureType.server,
    _ => null,
  };
}
