import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/post.dart';

abstract interface class PostRepository {
  Future<List<Post>> list();
  Future<Post> create(String title, String content);
}

class HttpPostRepository implements PostRepository {
  const HttpPostRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Post>> list() async {
    try {
      final json = await _client.get('/api/posts');
      return (json! as List)
          .map((item) => Post.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
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

  @override
  Future<Post> create(String title, String content) async {
    try {
      final json = await _client.post('/api/posts', {
        // v1.0.10 required this field. Secured backends ignore it and derive
        // the authoritative author from the authenticated principal.
        'authorUserId': ?_client.sessionUserId,
        'title': title,
        'content': content,
      });
      return Post.fromJson(Map<String, dynamic>.from(json! as Map));
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
    404 => AppFailureType.notFound,
    401 => AppFailureType.sessionExpired,
    403 => AppFailureType.forbidden,
    _ when statusCode >= 500 => AppFailureType.server,
    _ => null,
  };
}
