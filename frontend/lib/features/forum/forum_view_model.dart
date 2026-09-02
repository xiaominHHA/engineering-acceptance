import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../models/post.dart';
import 'post_repository.dart';

enum ForumLoadState { initial, loading, empty, success, failure }

class ForumViewModel extends ChangeNotifier {
  ForumViewModel(this._repository);

  final PostRepository _repository;
  bool _disposed = false;
  Future<void>? _activeLoad;
  int _contentRevision = 0;
  final Set<String> _deletedPostIds = {};

  ForumLoadState loadState = ForumLoadState.initial;
  List<Post> posts = const [];
  String? loadErrorMessage;
  bool isRefreshing = false;
  bool isPublishing = false;
  final Set<String> deletingPostIds = {};
  String? publishErrorMessage;
  String? deleteErrorMessage;
  bool sessionExpired = false;

  void clearPublishError() {
    if (publishErrorMessage == null) return;
    publishErrorMessage = null;
    _notify();
  }

  Future<void> load() {
    final activeLoad = _activeLoad;
    if (activeLoad != null) return activeLoad;

    late final Future<void> operation;
    operation = _load().whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
    _activeLoad = operation;
    return operation;
  }

  Future<void> _load() async {
    final hadPosts = posts.isNotEmpty;
    final revisionAtStart = _contentRevision;
    if (!hadPosts) loadState = ForumLoadState.loading;
    if (hadPosts) isRefreshing = true;
    loadErrorMessage = null;
    sessionExpired = false;
    _notify();
    try {
      final loaded = await _repository.list();
      posts = _contentRevision == revisionAtStart
          ? _normalized(loaded)
          : _normalized([...posts, ...loaded]);
      loadState = posts.isEmpty ? ForumLoadState.empty : ForumLoadState.success;
    } on AppFailure catch (failure) {
      loadErrorMessage = _loadMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      loadState = hadPosts ? ForumLoadState.success : ForumLoadState.failure;
    } catch (_) {
      loadErrorMessage = '帖子加载失败，请稍后重试';
      loadState = hadPosts ? ForumLoadState.success : ForumLoadState.failure;
    } finally {
      isRefreshing = false;
      _notify();
    }
  }

  Future<bool> publish(String title, String content) async {
    if (isPublishing) return false;
    isPublishing = true;
    publishErrorMessage = null;
    sessionExpired = false;
    _notify();
    try {
      final created = await _repository.create(title, content);
      _contentRevision++;
      posts = _normalized([created, ...posts]);
      loadState = ForumLoadState.success;
      loadErrorMessage = null;
      return true;
    } on AppFailure catch (failure) {
      publishErrorMessage = _publishMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } catch (_) {
      publishErrorMessage = '发布失败，请稍后重试';
      return false;
    } finally {
      isPublishing = false;
      _notify();
    }
  }

  Future<bool> delete(String postId) async {
    if (deletingPostIds.contains(postId)) return false;
    deletingPostIds.add(postId);
    deleteErrorMessage = null;
    sessionExpired = false;
    _notify();
    try {
      await _repository.delete(postId);
      _contentRevision++;
      _deletedPostIds.add(postId);
      posts = List.unmodifiable(posts.where((post) => post.id != postId));
      loadState = posts.isEmpty ? ForumLoadState.empty : ForumLoadState.success;
      return true;
    } on AppFailure catch (failure) {
      deleteErrorMessage = _deleteMessageFor(failure);
      sessionExpired = failure.type == AppFailureType.sessionExpired;
      return false;
    } catch (_) {
      deleteErrorMessage = '删除失败，请稍后重试';
      return false;
    } finally {
      deletingPostIds.remove(postId);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<Post> _normalized(Iterable<Post> source) {
    final byId = <String, Post>{};
    for (final post in source) {
      if (_deletedPostIds.contains(post.id)) continue;
      byId.putIfAbsent(post.id, () => post);
    }
    final indexed = byId.values.indexed.toList();
    indexed.sort((left, right) {
      final leftDate = left.$2.createdAt;
      final rightDate = right.$2.createdAt;
      if (leftDate == null && rightDate != null) return 1;
      if (leftDate != null && rightDate == null) return -1;
      final byDate = rightDate?.compareTo(leftDate!) ?? 0;
      return byDate != 0 ? byDate : left.$1.compareTo(right.$1);
    });
    return List.unmodifiable(indexed.map((entry) => entry.$2));
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
    AppFailureType.network => '无法连接服务器，请检查网络后重试',
    AppFailureType.server => '服务器暂时无法处理请求，请稍后重试',
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    AppFailureType.forbidden => '没有权限发布帖子',
    _ => '发布失败，请稍后重试',
  };

  String _deleteMessageFor(AppFailure failure) => switch (failure.type) {
    AppFailureType.featureUnavailable => '当前服务器版本暂不支持删除帖子',
    AppFailureType.notFound => '帖子不存在或已被删除',
    AppFailureType.forbidden => '只能删除自己发布的帖子',
    AppFailureType.sessionExpired => '登录已失效，请重新登录',
    AppFailureType.network => '无法连接服务器，帖子未删除',
    AppFailureType.server => '服务器暂时无法删除帖子，请稍后重试',
    _ => '删除失败，请稍后重试',
  };
}
