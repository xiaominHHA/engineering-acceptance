import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../models/comment.dart';
import '../../models/post.dart';

abstract interface class ForumRepository {
  Future<List<Post>> listPosts({required int page, int size = 20});
  Future<Post> getPost(String postId);
  Future<Post> createPost(String title, String content);
  Future<void> deletePost(String postId);
  Future<void> setLiked(String postId, {required bool liked});
  Future<List<Comment>> listComments(
    String postId, {
    required int page,
    int size = 30,
  });
  Future<Comment> createComment(
    String postId,
    String content, {
    String? replyToCommentId,
  });
  Future<void> deleteComment(String postId, String commentId);
}

class HttpForumRepository implements ForumRepository {
  const HttpForumRepository(this._client);
  final ApiClient _client;

  @override
  Future<List<Post>> listPosts({required int page, int size = 20}) async {
    final json = await _request(
      () => _client.get('/api/posts?page=$page&size=$size'),
    );
    return (json! as List)
        .map((item) => Post.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<Post> getPost(String postId) async => Post.fromJson(
    Map<String, dynamic>.from(
      (await _request(() => _client.get('/api/posts/$postId')))! as Map,
    ),
  );

  @override
  Future<Post> createPost(String title, String content) async {
    final json = await _request(
      () => _client.post('/api/posts', {
        // Temporary compatibility with v1.0.10. Secured backends ignore this
        // and derive the author exclusively from the bearer principal.
        'authorUserId': ?_client.sessionUserId,
        'title': title,
        'content': content,
      }),
    );
    return Post.fromJson(Map<String, dynamic>.from(json! as Map));
  }

  @override
  Future<void> deletePost(String postId) => _request(
    () => _client.delete('/api/posts/$postId'),
    deleteCompatibility: true,
  );

  @override
  Future<void> setLiked(String postId, {required bool liked}) => _request(
    () => liked
        ? _client.put('/api/posts/$postId/like', const {})
        : _client.delete('/api/posts/$postId/like'),
  );

  @override
  Future<List<Comment>> listComments(
    String postId, {
    required int page,
    int size = 30,
  }) async {
    final json = await _request(
      () => _client.get('/api/posts/$postId/comments?page=$page&size=$size'),
    );
    return (json! as List)
        .map((item) => Comment.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<Comment> createComment(
    String postId,
    String content, {
    String? replyToCommentId,
  }) async {
    final json = await _request(
      () => _client.post('/api/posts/$postId/comments', {
        'content': content,
        'replyToCommentId': ?replyToCommentId,
      }),
    );
    return Comment.fromJson(Map<String, dynamic>.from(json! as Map));
  }

  @override
  Future<void> deleteComment(String postId, String commentId) =>
      _request(() => _client.delete('/api/posts/$postId/comments/$commentId'));

  Future<T> _request<T>(
    Future<T> Function() request, {
    bool deleteCompatibility = false,
  }) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw AppFailure.fromApiException(
        error,
        legacyStatusFallback: deleteCompatibility
            ? _legacyDeleteStatus
            : _legacyStatus,
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

  static AppFailureType? _legacyDeleteStatus(int statusCode) =>
      switch (statusCode) {
        401 => AppFailureType.sessionExpired,
        403 => AppFailureType.forbidden,
        404 || 405 => AppFailureType.featureUnavailable,
        _ when statusCode >= 500 => AppFailureType.server,
        _ => null,
      };
}
