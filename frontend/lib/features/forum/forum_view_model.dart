import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/post.dart';
import 'forum_repository.dart';

enum ForumLoadState { initial, loading, empty, success, failure }

class ForumViewModel extends ChangeNotifier {
  ForumViewModel(this._repository);

  static const pageSize = 20;
  final ForumRepository _repository;
  bool _disposed = false;
  int _contentRevision = 0;
  final Set<String> _deletedPostIds = {};

  ForumLoadState loadState = ForumLoadState.initial;
  List<Post> posts = const [];
  String? loadErrorMessage;
  String? actionErrorMessage;
  bool isRefreshing = false;
  bool isLoadingMore = false;
  bool isPublishing = false;
  bool hasMore = true;
  int _nextPage = 0;
  final Set<String> deletingPostIds = {};
  final Set<String> likingPostIds = {};
  bool sessionExpired = false;

  Future<void> load() =>
      loadState == ForumLoadState.initial ? loadInitial() : refresh();

  Future<void> loadInitial() async {
    if (loadState == ForumLoadState.loading) return;
    loadState = ForumLoadState.loading;
    loadErrorMessage = null;
    _notify();
    await _replaceFirstPage(keepExistingOnFailure: false);
  }

  Future<void> refresh() async {
    if (isRefreshing) return;
    isRefreshing = true;
    loadErrorMessage = null;
    _notify();
    await _replaceFirstPage(keepExistingOnFailure: true);
    isRefreshing = false;
    _notify();
  }

  Future<void> _replaceFirstPage({required bool keepExistingOnFailure}) async {
    final revisionAtStart = _contentRevision;
    try {
      final loaded = await _repository.listPosts(page: 0, size: pageSize);
      posts = _contentRevision == revisionAtStart
          ? _normalized(loaded)
          : _normalized([...posts, ...loaded]);
      _nextPage = 1;
      hasMore = loaded.length == pageSize;
      loadState = posts.isEmpty ? ForumLoadState.empty : ForumLoadState.success;
    } on AppFailure catch (failure) {
      loadErrorMessage = _loadMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      loadState = keepExistingOnFailure && posts.isNotEmpty
          ? ForumLoadState.success
          : ForumLoadState.failure;
    } catch (_) {
      loadErrorMessage = '帖子加载失败，请稍后重试';
      loadState = keepExistingOnFailure && posts.isNotEmpty
          ? ForumLoadState.success
          : ForumLoadState.failure;
    }
    _notify();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || isRefreshing || !hasMore) return;
    isLoadingMore = true;
    actionErrorMessage = null;
    _notify();
    try {
      final loaded = await _repository.listPosts(
        page: _nextPage,
        size: pageSize,
      );
      posts = _normalized([...posts, ...loaded]);
      _nextPage++;
      hasMore = loaded.length == pageSize;
    } on AppFailure catch (failure) {
      actionErrorMessage = _loadMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
    } finally {
      isLoadingMore = false;
      _notify();
    }
  }

  Future<bool> publish(String title, String content) async {
    if (isPublishing) return false;
    isPublishing = true;
    actionErrorMessage = null;
    sessionExpired = false;
    _notify();
    try {
      final created = await _repository.createPost(title, content);
      _contentRevision++;
      posts = _normalized([created, ...posts]);
      loadState = ForumLoadState.success;
      return true;
    } on AppFailure catch (failure) {
      actionErrorMessage = _publishMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } catch (_) {
      actionErrorMessage = '发布失败，请稍后重试';
      return false;
    } finally {
      isPublishing = false;
      _notify();
    }
  }

  Future<bool> delete(String postId) async {
    if (deletingPostIds.contains(postId)) return false;
    deletingPostIds.add(postId);
    actionErrorMessage = null;
    _notify();
    try {
      await _repository.deletePost(postId);
      _contentRevision++;
      _deletedPostIds.add(postId);
      posts = List.unmodifiable(posts.where((post) => post.id != postId));
      loadState = posts.isEmpty ? ForumLoadState.empty : ForumLoadState.success;
      return true;
    } on AppFailure catch (failure) {
      actionErrorMessage = _deleteMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } finally {
      deletingPostIds.remove(postId);
      _notify();
    }
  }

  Future<void> toggleLike(Post post) async {
    if (likingPostIds.contains(post.id)) return;
    likingPostIds.add(post.id);
    actionErrorMessage = null;
    final nextLiked = !post.likedByCurrentUser;
    final optimistic = post.copyWith(
      likedByCurrentUser: nextLiked,
      likeCount: (post.likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 31),
    );
    mergePost(optimistic);
    try {
      await _repository.setLiked(post.id, liked: nextLiked);
    } on AppFailure catch (failure) {
      mergePost(post);
      actionErrorMessage = _actionMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
    } finally {
      likingPostIds.remove(post.id);
      _notify();
    }
  }

  void mergePost(Post updated) {
    posts = _normalized([
      updated,
      ...posts.where((post) => post.id != updated.id),
    ]);
    _notify();
  }

  List<Post> _normalized(Iterable<Post> source) {
    final byId = <String, Post>{};
    for (final post in source) {
      if (!_deletedPostIds.contains(post.id)) {
        byId.putIfAbsent(post.id, () => post);
      }
    }
    final result = byId.values.toList()
      ..sort((a, b) {
        final byDate = (b.createdAt ?? DateTime(1970)).compareTo(
          a.createdAt ?? DateTime(1970),
        );
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
    return List.unmodifiable(result);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _loadMessageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.server => '服务器暂时无法加载帖子，请稍后重试',
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    _ => '帖子加载失败，请稍后重试',
  };

  String _publishMessageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.validation when failure.fieldErrors.containsKey('title') =>
      '标题不符合要求，请检查后重试',
    AppFailureType.validation when failure.fieldErrors.containsKey('content') =>
      '正文不符合要求，请检查后重试',
    AppFailureType.validation
        when failure.fieldErrors.containsKey('authorUserId') =>
      '当前应用与服务器版本暂不兼容，请更新应用后重试',
    AppFailureType.validation => '提交信息不符合要求，请检查后重试',
    _ => _actionMessageFor(failure),
  };

  String _deleteMessageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.featureUnavailable => '当前服务器版本暂不支持删除帖子',
    AppFailureType.notFound => '帖子不存在或已被删除',
    AppFailureType.forbidden => '只能删除自己发布的帖子',
    _ => _actionMessageFor(failure),
  };

  String _actionMessageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.server => '服务器暂时无法处理请求，请稍后重试',
    AppFailureType.notFound => '帖子不存在或已被删除',
    _ => '操作失败，请稍后重试',
  };
}
