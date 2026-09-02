import 'package:engineering_acceptance_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for the expected widget');
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete isolated user and forum flow', (tester) async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final username = 'integration-$suffix';
    const password = 'integration-password-123';
    const nickname = 'Integration User';
    final postTitle = 'Integration post $suffix';

    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('第一次使用？创建账号'));
    await tester.pump();
    await tester.enterText(field('用户名'), username);
    await tester.enterText(field('密码'), password);
    await tester.enterText(field('昵称'), nickname);
    await tapVisible(tester, find.text('注册并进入'));
    await waitFor(tester, find.text('个人资料'));

    await tester.tap(find.byIcon(Icons.logout));
    await waitFor(tester, find.text('第一次使用？创建账号'));
    await tester.tap(find.text('第一次使用？创建账号'));
    await tester.pump();
    await tester.enterText(field('用户名'), username);
    await tester.enterText(field('密码'), password);
    await tester.enterText(field('昵称'), nickname);
    await tapVisible(tester, find.text('注册并进入'));
    await waitFor(tester, find.text('用户名已存在，请更换用户名'));

    await tester.tap(find.text('已有账号？返回登录'));
    await tester.pump();
    await tester.enterText(field('用户名'), username);
    await tester.enterText(field('密码'), 'wrong-password');
    await tapVisible(tester, find.text('登录'));
    await waitFor(tester, find.text('用户名或密码错误'));

    await tester.enterText(field('密码'), password);
    await tapVisible(tester, find.text('登录'));
    await waitFor(tester, find.text('个人资料'));

    await tester.enterText(field('昵称'), 'Updated Integration User');
    await tester.tap(find.byKey(const Key('birthday-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${DateTime.now().day}').last);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.enterText(field('学校'), 'Integration School');
    await tester.enterText(field('班级'), 'Integration Class');
    await tapVisible(tester, find.text('保存资料'));
    await waitFor(tester, find.text('已保存'));

    await tester.tap(find.text('论坛'));
    await tester.pump();
    await tester.tap(find.text('发布'));
    await tester.pumpAndSettle();
    await tester.enterText(field('标题'), postTitle);
    await tester.enterText(field('内容'), 'Integration test content');
    await tapVisible(tester, find.text('发布帖子'));
    await waitFor(tester, find.text('发布成功'));
    await waitFor(tester, find.text(postTitle));
  });
}
