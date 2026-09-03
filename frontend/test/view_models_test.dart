import 'dart:async';

import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/core/session/session_storage.dart';
import 'package:engineering_acceptance_app/features/auth/auth_repository.dart';
import 'package:engineering_acceptance_app/features/auth/login_view_model.dart';
import 'package:engineering_acceptance_app/features/forum/forum_view_model.dart';
import 'package:engineering_acceptance_app/features/forum/forum_repository.dart';
import 'package:engineering_acceptance_app/features/forum/post_detail_view_model.dart';
import 'package:engineering_acceptance_app/features/profile/profile_view_model.dart';
import 'package:engineering_acceptance_app/features/profile/user_repository.dart';
import 'package:engineering_acceptance_app/main.dart';
import 'package:engineering_acceptance_app/models/post.dart';
import 'package:engineering_acceptance_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = User(id: 1, username: 'tester', nickname: 'Tester');

class ControlledAuthRepository implements AuthRepository {
  final loginCompleter = Completer<User>();
  int loginCalls = 0;

  @override
  Future<void> logout() async {}

  @override
  Future<StoredSession?> restoreSession() async => null;

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<User> login(String username, String password) {
    loginCalls++;
    return loginCompleter.future;
  }

  @override
  Future<User> register(String username, String password, String nickname) =>
      Future.value(testUser);
}

class FakeUserRepository implements UserRepository {
  Object? error;

  @override
  Future<User> get(int userId) async => testUser;

  @override
  Future<User> update(
    int userId, {
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) async {
    if (error case final value?) throw value;
    return User(id: userId, username: 'tester', nickname: nickname);
  }
}

class FakePostRepository implements ForumRepository {
  List<Post> listedPosts = const [];
  Object? listError;
  Object? createError;
  Object? deleteError;
  final createCompleter = Completer<Post>();
  int createCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> deletePost(String postId) async {
    deleteCalls++;
    if (deleteError case final error?) throw error;
  }

  @override
  Future<List<Post>> listPosts({required int page, int size = 20}) async {
    if (listError case final error?) throw error;
    return listedPosts;
  }

  @override
  Future<Post> createPost(String title, String content) {
    createCalls++;
    if (createError case final error?) return Future.error(error);
    return createCompleter.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ControlledPostRepository implements ForumRepository {
  final initialList = Completer<List<Post>>();
  final createCompleter = Completer<Post>();
  int listCalls = 0;

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<List<Post>> listPosts({required int page, int size = 20}) {
    listCalls++;
    return initialList.future;
  }

  @override
  Future<Post> createPost(String title, String content) =>
      createCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'login view model exposes loading, success, and prevents duplicates',
    () async {
      final repository = ControlledAuthRepository();
      final viewModel = LoginViewModel(repository);

      final first = viewModel.login('tester', 'password123');
      expect(viewModel.isSubmitting, isTrue);

      final duplicate = await viewModel.login('tester', 'password123');
      expect(duplicate, isNull);
      expect(repository.loginCalls, 1);

      repository.loginCompleter.complete(testUser);
      expect(await first, testUser);
      expect(viewModel.isSubmitting, isFalse);
      expect(viewModel.errorMessage, isNull);
    },
  );

  test('login view model returns from loading with a typed failure', () async {
    final repository = ControlledAuthRepository();
    final viewModel = LoginViewModel(repository);

    final login = viewModel.login('tester', 'wrong-password');
    expect(viewModel.isSubmitting, isTrue);

    repository.loginCompleter.completeError(
      const AppFailure(AppFailureType.invalidCredentials),
    );
    expect(await login, isNull);
    expect(viewModel.isSubmitting, isFalse);
    expect(viewModel.errorMessage, '登录用户名或密码错误');
  });

  test('async completion after view model disposal does not notify', () async {
    final repository = ControlledAuthRepository();
    final viewModel = LoginViewModel(repository);
    final login = viewModel.login('tester', 'password123');

    viewModel.dispose();
    repository.loginCompleter.complete(testUser);

    expect(await login, testUser);
  });

  test('profile view model exposes failure and returns to idle', () async {
    final repository = FakeUserRepository()
      ..error = const AppFailure(AppFailureType.validation);
    final viewModel = ProfileViewModel(repository, testUser);

    final result = await viewModel.save(nickname: '');

    expect(result, isNull);
    expect(viewModel.isSaving, isFalse);
    expect(viewModel.errorMessage, '资料输入不符合要求，请检查后重试');
  });

  testWidgets('authenticated shell leaves the session after auth expiry', (
    tester,
  ) async {
    final userRepository = FakeUserRepository()
      ..error = const AppFailure(AppFailureType.sessionExpired);
    final profileViewModel = ProfileViewModel(userRepository, testUser);
    final postRepository = FakePostRepository();
    final forumViewModel = ForumViewModel(postRepository);
    var expiryCallbacks = 0;
    addTearDown(profileViewModel.dispose);
    addTearDown(forumViewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          profileViewModel: profileViewModel,
          forumViewModel: forumViewModel,
          currentUserId: testUser.id,
          onUpdate: (_) async {},
          onLogout: () async {},
          onSessionExpired: () async {
            expiryCallbacks++;
          },
          createDetailViewModel: (post) =>
              PostDetailViewModel(postRepository, post),
        ),
      ),
    );
    await profileViewModel.save(nickname: testUser.nickname);
    await tester.pump();

    expect(profileViewModel.sessionExpired, isTrue);
    expect(expiryCallbacks, 1);
  });

  test(
    'forum distinguishes empty, success, failure, and preserves posts',
    () async {
      final repository = FakePostRepository();
      final viewModel = ForumViewModel(repository);

      await viewModel.load();
      expect(viewModel.loadState, ForumLoadState.empty);

      repository.listedPosts = const [
        Post(id: 'post-1', authorUserId: 1, title: 'Title', content: 'Content'),
      ];
      await viewModel.load();
      expect(viewModel.loadState, ForumLoadState.success);
      expect(viewModel.posts, hasLength(1));

      repository.listError = const AppFailure(AppFailureType.network);
      await viewModel.load();
      expect(viewModel.loadState, ForumLoadState.success);
      expect(viewModel.posts, hasLength(1));
      expect(viewModel.loadErrorMessage, '无法连接服务器，请检查网络后重试');
    },
  );

  test('forum prevents duplicate publish requests', () async {
    final repository = FakePostRepository();
    final viewModel = ForumViewModel(repository);

    final first = viewModel.publish('Title', 'Content');
    expect(viewModel.isPublishing, isTrue);

    expect(await viewModel.publish('Title', 'Content'), isFalse);
    expect(repository.createCalls, 1);

    repository.createCompleter.complete(
      const Post(
        id: 'post-1',
        authorUserId: 1,
        title: 'Title',
        content: 'Content',
      ),
    );
    expect(await first, isTrue);
    expect(viewModel.isPublishing, isFalse);
    expect(viewModel.posts.single.id, 'post-1');
  });

  test('forum explains validation field errors accurately', () async {
    Future<String?> messageFor(Map<String, String> fieldErrors) async {
      final repository = FakePostRepository()
        ..createError = AppFailure(
          AppFailureType.validation,
          fieldErrors: fieldErrors,
        );
      final viewModel = ForumViewModel(repository);
      addTearDown(viewModel.dispose);
      await viewModel.publish('早上好', '吃早餐了吗');
      return viewModel.actionErrorMessage;
    }

    expect(await messageFor({'title': 'must not be blank'}), '标题不符合要求，请检查后重试');
    expect(
      await messageFor({'content': 'size must be at most 10000'}),
      '正文不符合要求，请检查后重试',
    );
    expect(
      await messageFor({'authorUserId': 'must not be null'}),
      '当前应用与服务器版本暂不兼容，请更新应用后重试',
    );
  });

  test('forum preserves a created post when an older load completes', () async {
    final repository = ControlledPostRepository();
    final viewModel = ForumViewModel(repository);
    const publishedPost = Post(
      id: 'new-post',
      authorUserId: 1,
      title: 'Latest',
      content: 'Published while initial load was pending',
    );

    final initialLoad = viewModel.load();
    final publish = viewModel.publish(
      publishedPost.title,
      publishedPost.content,
    );

    repository.createCompleter.complete(publishedPost);
    expect(await publish, isTrue);
    expect(viewModel.posts, contains(publishedPost));

    repository.initialList.complete(const []);
    await initialLoad;
    expect(repository.listCalls, 1);
    expect(viewModel.posts, contains(publishedPost));
    expect(viewModel.loadState, ForumLoadState.success);
  });

  test('forum deduplicates ids and keeps stable newest-first order', () async {
    final repository = FakePostRepository();
    final older = Post(
      id: 'older',
      authorUserId: 1,
      title: 'Older',
      content: 'Older',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final newer = Post(
      id: 'newer',
      authorUserId: 1,
      title: 'Newer',
      content: 'Newer',
      createdAt: DateTime.utc(2026, 2, 1),
    );
    repository.listedPosts = [older, newer, older];
    final viewModel = ForumViewModel(repository);

    await viewModel.load();

    expect(viewModel.posts.map((post) => post.id), ['newer', 'older']);
  });

  test(
    'forum removes only after delete success and retains failed post',
    () async {
      const owned = Post(
        id: 'owned',
        authorUserId: 1,
        title: 'Owned',
        content: 'Content',
      );
      final repository = FakePostRepository()..listedPosts = const [owned];
      final viewModel = ForumViewModel(repository);
      await viewModel.load();

      repository.deleteError = const AppFailure(
        AppFailureType.featureUnavailable,
      );
      expect(await viewModel.delete(owned.id), isFalse);
      expect(viewModel.posts, contains(owned));
      expect(viewModel.actionErrorMessage, '当前服务器版本暂不支持删除帖子');

      repository.deleteError = null;
      expect(await viewModel.delete(owned.id), isTrue);
      expect(viewModel.posts, isEmpty);
      expect(repository.deleteCalls, 2);
    },
  );
}
