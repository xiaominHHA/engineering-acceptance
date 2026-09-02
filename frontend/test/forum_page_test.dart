import 'dart:async';

import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/features/forum/forum_page.dart';
import 'package:engineering_acceptance_app/features/forum/forum_view_model.dart';
import 'package:engineering_acceptance_app/features/forum/post_repository.dart';
import 'package:engineering_acceptance_app/models/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const existingPost = Post(
  id: 'existing',
  authorUserId: 1,
  title: 'Existing title',
  content: 'Existing content',
);
const publishedPost = Post(
  id: 'published',
  authorUserId: 1,
  title: '早上好',
  content: '吃早餐了吗',
);

class QueuePostRepository implements PostRepository {
  final listResults = <Object>[];
  Completer<Post>? controlledCreate;
  Object? createError;
  int listCalls = 0;
  int createCalls = 0;

  @override
  Future<List<Post>> list() async {
    listCalls++;
    final result = listResults.removeAt(0);
    if (result is Future<List<Post>>) return result;
    if (result is List<Post>) return result;
    throw result;
  }

  @override
  Future<Post> create(String title, String content) async {
    createCalls++;
    if (createError case final value?) throw value;
    final completer = controlledCreate;
    if (completer != null) return completer.future;
    return Post(
      id: publishedPost.id,
      authorUserId: 1,
      title: title,
      content: content,
    );
  }
}

Future<ForumViewModel> pumpForum(
  WidgetTester tester,
  QueuePostRepository repository, {
  Size size = const Size(800, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final viewModel = ForumViewModel(repository);
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: ForumPage(viewModel: viewModel)),
    ),
  );
  return viewModel;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> openComposer(WidgetTester tester) async {
  final button = tester.widget<FloatingActionButton>(
    find.byType(FloatingActionButton),
  );
  button.onPressed!();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows loading, empty, success, and load failure with retry', (
    tester,
  ) async {
    final initial = Completer<List<Post>>();
    final repository = QueuePostRepository()
      ..listResults.addAll([
        initial.future,
        const AppFailure(AppFailureType.network),
        <Post>[existingPost],
      ]);
    final viewModel = await pumpForum(tester, repository);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    initial.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('还没有帖子'), findsOneWidget);

    await viewModel.load();
    await tester.pumpAndSettle();
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('Existing title'), findsOneWidget);
  });

  testWidgets('failed first load exposes retry action', (tester) async {
    final repository = QueuePostRepository()
      ..listResults.addAll([
        const AppFailure(AppFailureType.network),
        <Post>[existingPost],
      ]);
    await pumpForum(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('Existing title'), findsOneWidget);
  });

  testWidgets('validates empty and over-limit post fields', (tester) async {
    final repository = QueuePostRepository()
      ..listResults.addAll([
        <Post>[],
        <Post>[publishedPost],
      ]);
    await pumpForum(tester, repository);
    await tester.pumpAndSettle();

    await openComposer(tester);

    await tester.tap(find.text('发布帖子'));
    await tester.pump();
    expect(find.text('标题不能为空'), findsOneWidget);
    expect(find.text('内容不能为空'), findsOneWidget);

    await tester.enterText(field('标题'), 'a' * 201);
    await tester.enterText(field('内容'), 'b' * 10001);
    await tester.tap(find.text('发布帖子'));
    await tester.pump();
    expect(find.text('标题不能超过 200 位'), findsOneWidget);
    expect(find.text('内容不能超过 10000 位'), findsOneWidget);
    expect(repository.createCalls, 0);

    await tester.enterText(field('标题'), 'a' * 200);
    await tester.enterText(field('内容'), 'b' * 10000);
    await tester.tap(find.text('发布帖子'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
  });

  testWidgets('publishing disables button and failure is explained', (
    tester,
  ) async {
    final repository = QueuePostRepository()
      ..listResults.add(<Post>[])
      ..controlledCreate = Completer<Post>();
    await pumpForum(tester, repository);
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(field('标题'), 'Title');
    await tester.enterText(field('内容'), 'Content');
    await tester.tap(find.text('发布帖子'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.controlledCreate!.completeError(
      const AppFailure(AppFailureType.network),
    );
    await tester.pumpAndSettle();
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);
    expect(tester.widget<TextFormField>(field('标题')).controller?.text, 'Title');
    expect(
      tester.widget<TextFormField>(field('内容')).controller?.text,
      'Content',
    );
    expect(find.text('发布新帖子'), findsOneWidget);
  });

  testWidgets('publish success clears draft and inserts server post', (
    tester,
  ) async {
    final repository = QueuePostRepository()..listResults.add(<Post>[]);
    await pumpForum(tester, repository);
    await tester.pumpAndSettle();
    await openComposer(tester);
    await tester.enterText(field('标题'), publishedPost.title);
    await tester.enterText(field('内容'), publishedPost.content);
    await tester.tap(find.text('发布帖子'));
    await tester.pumpAndSettle();

    expect(find.text('发布成功'), findsOneWidget);
    expect(find.text(publishedPost.title), findsOneWidget);
    expect(repository.listCalls, 1);
    await tester.pump(const Duration(seconds: 5));
    await openComposer(tester);
    expect(tester.widget<TextFormField>(field('标题')).controller?.text, isEmpty);
    expect(tester.widget<TextFormField>(field('内容')).controller?.text, isEmpty);
  });

  testWidgets('refresh failure preserves existing posts', (tester) async {
    final repository = QueuePostRepository()
      ..listResults.addAll([
        <Post>[existingPost],
        const AppFailure(AppFailureType.network),
      ]);
    final viewModel = await pumpForum(tester, repository);
    await tester.pumpAndSettle();
    await viewModel.load();
    await tester.pumpAndSettle();

    expect(find.text('Existing title'), findsOneWidget);
    expect(find.textContaining('无法连接服务器，请检查网络后重试'), findsOneWidget);
  });

  testWidgets('small viewport and large text render without exceptions', (
    tester,
  ) async {
    final repository = QueuePostRepository()..listResults.add(<Post>[]);
    await pumpForum(
      tester,
      repository,
      size: const Size(320, 480),
      textScale: 2,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('发布'), findsOneWidget);
  });
}
