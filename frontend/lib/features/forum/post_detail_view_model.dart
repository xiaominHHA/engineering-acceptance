import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import 'forum_repository.dart';

class PostDetailViewModel extends ChangeNotifier {
  PostDetailViewModel(this._repository, this.post);

  static const commentPageSize = 30;
  final ForumRepository _repository;
  bool _disposed = false;
  int _nextPage = 0;

  Post post;
  List<Comment> comments = const [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool isSubmitting = false;
  bool isLiking = false;
  bool hasMore = true;
  String? errorMessage;
  String? actionErrorMessage;
  String? replyToCommentId;
  String? replyToNickname;
  final Set<String> deletingCommentIds = {};
  bool sessionExpired = false;

  Future<void> load() async {
    if (isLoading) return;
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      final results = await Future.wait([
        _repository.getPost(post.id),
        _repository.listComments(post.id, page: 0, size: commentPageSize),
      ]);
      post = results[0] as Post;
      comments = _dedup(results[1] as List<Comment>);
      _nextPage = 1;
      hasMore = comments.length == commentPageSize;
    } on AppFailure catch (failure) {
      errorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    _notify();
    try {
      final loaded = await _repository.listComments(
        post.id,
        page: _nextPage,
        size: commentPageSize,
      );
      comments = _dedup([...comments, ...loaded]);
      _nextPage++;
      hasMore = loaded.length == commentPageSize;
    } on AppFailure catch (failure) {
      actionErrorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
    } finally {
      isLoadingMore = false;
      _notify();
    }
  }

  Future<bool> submitComment(String content) async {
    if (isSubmitting) return false;
    isSubmitting = true;
    actionErrorMessage = null;
    _notify();
    try {
      final created = await _repository.createComment(
        post.id,
        content,
        replyToCommentId: replyToCommentId,
      );
      comments = _dedup([...comments, created]);
      post = post.copyWith(commentCount: post.commentCount + 1);
      clearReply(notify: false);
      return true;
    } on AppFailure catch (failure) {
      actionErrorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } finally {
      isSubmitting = false;
      _notify();
    }
  }

  Future<void> toggleLike() async {
    if (isLiking) return;
    isLiking = true;
    final previous = post;
    final liked = !post.likedByCurrentUser;
    post = post.copyWith(
      likedByCurrentUser: liked,
      likeCount: (post.likeCount + (liked ? 1 : -1)).clamp(0, 1 << 31),
    );
    _notify();
    try {
      await _repository.setLiked(post.id, liked: liked);
    } on AppFailure catch (failure) {
      post = previous;
      actionErrorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
    } finally {
      isLiking = false;
      _notify();
    }
  }

  void replyTo(Comment comment) {
    replyToCommentId = comment.id;
    replyToNickname = comment.authorNickname;
    _notify();
  }

  void clearReply({bool notify = true}) {
    replyToCommentId = null;
    replyToNickname = null;
    if (notify) _notify();
  }

  Future<bool> deleteComment(Comment comment) async {
    if (deletingCommentIds.contains(comment.id)) return false;
    deletingCommentIds.add(comment.id);
    _notify();
    try {
      await _repository.deleteComment(post.id, comment.id);
      comments = List.unmodifiable(
        comments.where((item) => item.id != comment.id),
      );
      post = post.copyWith(
        commentCount: (post.commentCount - 1).clamp(0, 1 << 31),
      );
      return true;
    } on AppFailure catch (failure) {
      actionErrorMessage = _messageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } finally {
      deletingCommentIds.remove(comment.id);
      _notify();
    }
  }

  List<Comment> _dedup(Iterable<Comment> values) {
    final byId = <String, Comment>{for (final value in values) value.id: value};
    final result = byId.values.toList()
      ..sort(
        (a, b) => (a.createdAt ?? DateTime(1970)).compareTo(
          b.createdAt ?? DateTime(1970),
        ),
      );
    return List.unmodifiable(result);
  }

  String _messageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.validation => '评论内容或回复对象不符合要求',
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    AppFailureType.forbidden => '只能删除自己的评论',
    AppFailureType.notFound => '帖子或评论不存在',
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.server => '服务器暂时无法处理请求，请稍后重试',
    _ => '操作失败，请稍后重试',
  };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
