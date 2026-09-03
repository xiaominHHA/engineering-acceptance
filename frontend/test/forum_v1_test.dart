import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/features/forum/forum_repository.dart';
import 'package:engineering_acceptance_app/features/forum/forum_view_model.dart';
import 'package:engineering_acceptance_app/features/forum/post_detail_page.dart';
import 'package:engineering_acceptance_app/features/forum/post_detail_view_model.dart';
import 'package:engineering_acceptance_app/models/comment.dart';
import 'package:engineering_acceptance_app/models/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeForumRepository implements ForumRepository {
  final Map<int, List<Post>> pages = {};
  List<Comment> comments = const [];
  Object? likeError;
  Object? commentError;
  Object? deleteCommentError;
  int likeCalls = 0;
  int commentCalls = 0;
  late Post detailPost;

  @override
  Future<List<Post>> listPosts({required int page, int size = 20}) async =>
      pages[page] ?? const [];

  @override
  Future<Post> getPost(String postId) async => detailPost;

  @override
  Future<void> setLiked(String postId, {required bool liked}) async {
    likeCalls++;
    if (likeError case final value?) throw value;
  }

  @override
  Future<List<Comment>> listComments(
    String postId, {
    required int page,
    int size = 30,
  }) async => page == 0 ? comments : const [];

  @override
  Future<Comment> createComment(
    String postId,
    String content, {
    String? replyToCommentId,
  }) async {
    commentCalls++;
    if (commentError case final value?) throw value;
    return Comment(
      id: 'created-comment',
      postId: postId,
      authorUserId: 1,
      authorNickname: '我',
      content: content,
      replyToCommentId: replyToCommentId,
      replyToNickname: replyToCommentId == null ? null : '同学',
      createdAt: DateTime.utc(2026, 2),
    );
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    if (deleteCommentError case final value?) throw value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Post post(String id, int day, {bool liked = false, int likes = 0}) => Post(
  id: id,
  authorUserId: 1,
  authorNickname: 'Tester',
  title: 'Title $id',
  content: 'Content $id',
  createdAt: DateTime.utc(2026, 1, day),
  likedByCurrentUser: liked,
  likeCount: likes,
);

void main() {
  test(
    'feed loads more, deduplicates ids, and keeps newest-first order',
    () async {
      final first = List.generate(20, (index) => post('p$index', index + 1));
      final repository = FakeForumRepository()
        ..pages[0] = first
        ..pages[1] = [first.last, post('new-page', 31)];
      final viewModel = ForumViewModel(repository);

      await viewModel.loadInitial();
      expect(viewModel.hasMore, isTrue);
      await viewModel.loadMore();

      expect(viewModel.posts.map((value) => value.id).toSet(), hasLength(21));
      expect(viewModel.posts.first.id, 'new-page');
      expect(viewModel.hasMore, isFalse);
    },
  );

  test('like is optimistic and rolls back when repository fails', () async {
    final original = post('liked', 1, likes: 2);
    final repository = FakeForumRepository()
      ..pages[0] = [original]
      ..likeError = const AppFailure(AppFailureType.network);
    final viewModel = ForumViewModel(repository);
    await viewModel.loadInitial();

    final operation = viewModel.toggleLike(original);
    expect(viewModel.posts.single.likedByCurrentUser, isTrue);
    expect(viewModel.posts.single.likeCount, 3);
    await operation;

    expect(viewModel.posts.single.likedByCurrentUser, isFalse);
    expect(viewModel.posts.single.likeCount, 2);
    expect(repository.likeCalls, 1);
  });

  test(
    'comment failure retains draft responsibility and success merges reply',
    () async {
      final repository = FakeForumRepository()
        ..detailPost = post('detail', 1)
        ..comments = [
          Comment(
            id: 'target',
            postId: 'detail',
            authorUserId: 2,
            authorNickname: '同学',
            content: '你好',
            createdAt: DateTime.utc(2026, 1),
          ),
        ];
      final viewModel = PostDetailViewModel(repository, repository.detailPost);
      await viewModel.load();
      viewModel.replyTo(viewModel.comments.single);
      repository.commentError = const AppFailure(AppFailureType.network);

      expect(await viewModel.submitComment('保留的草稿'), isFalse);
      expect(viewModel.replyToCommentId, 'target');
      repository.commentError = null;
      expect(await viewModel.submitComment('回复内容'), isTrue);

      expect(viewModel.comments.last.content, '回复内容');
      expect(viewModel.comments.last.replyToNickname, '同学');
      expect(viewModel.replyToCommentId, isNull);
      expect(viewModel.post.commentCount, 1);
    },
  );

  testWidgets('post detail renders reply and preserves failed comment input', (
    tester,
  ) async {
    final repository = FakeForumRepository()
      ..detailPost = post('detail', 1)
      ..comments = const []
      ..commentError = const AppFailure(AppFailureType.network);
    final viewModel = PostDetailViewModel(repository, repository.detailPost);

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailPage(
          viewModel: viewModel,
          currentUserId: 1,
          onSessionExpired: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不能丢失');
    await tester.tap(find.byTooltip('发送评论'));
    await tester.pumpAndSettle();

    expect(find.text('不能丢失'), findsOneWidget);
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);
  });
}
