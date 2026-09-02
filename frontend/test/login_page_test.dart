import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/core/session/session_storage.dart';
import 'package:engineering_acceptance_app/features/auth/auth_repository.dart';
import 'package:engineering_acceptance_app/features/auth/login_page.dart';
import 'package:engineering_acceptance_app/features/auth/login_view_model.dart';
import 'package:engineering_acceptance_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  int registerCalls = 0;
  Object? loginError;
  Object? registerError;

  static const user = User(id: 1, username: 'tester', nickname: 'Tester');

  @override
  Future<void> logout() async {}

  @override
  Future<StoredSession?> restoreSession() async => null;

  @override
  Future<void> updateUser(User user) async {}

  @override
  Future<User> login(String username, String password) async {
    loginCalls++;
    if (loginError case final error?) throw error;
    return user;
  }

  @override
  Future<User> register(
    String username,
    String password,
    String nickname,
  ) async {
    registerCalls++;
    if (registerError case final error?) throw error;
    return user;
  }
}

Future<void> pumpLoginPage(
  WidgetTester tester,
  FakeAuthRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LoginPage(viewModel: LoginViewModel(repository), onLogin: (_) {}),
    ),
  );
}

Future<void> switchToRegister(WidgetTester tester) async {
  await tester.tap(find.text('第一次使用？创建账号'));
  await tester.pump();
}

void main() {
  testWidgets('password visibility can be toggled', (tester) async {
    await pumpLoginPage(tester, FakeAuthRepository());

    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, '密码'),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('隐藏密码'), findsOneWidget);
  });

  testWidgets('register mode shows password length requirement', (
    tester,
  ) async {
    await pumpLoginPage(tester, FakeAuthRepository());
    await switchToRegister(tester);

    expect(find.text('密码长度 8～72 位'), findsOneWidget);
  });

  testWidgets('register form keeps text fields before the secure keyboard', (
    tester,
  ) async {
    await pumpLoginPage(tester, FakeAuthRepository());
    await switchToRegister(tester);

    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.text('用户名')).dy,
      lessThan(tester.getTopLeft(find.text('昵称')).dy),
    );
    expect(
      tester.getTopLeft(find.text('昵称')).dy,
      lessThan(tester.getTopLeft(find.text('密码')).dy),
    );

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();

    final usernameField = fields[0];
    expect(usernameField.keyboardType, TextInputType.text);
    expect(usernameField.autocorrect, isFalse);
    expect(usernameField.enableSuggestions, isFalse);
    expect(usernameField.autofillHints, contains(AutofillHints.username));
    expect(usernameField.textInputAction, TextInputAction.next);

    final nicknameField = fields[1];
    expect(nicknameField.keyboardType, TextInputType.name);
    expect(nicknameField.autocorrect, isTrue);
    expect(nicknameField.enableSuggestions, isTrue);
    expect(nicknameField.obscureText, isFalse);
    expect(nicknameField.autofillHints, isNull);
    expect(nicknameField.textInputAction, TextInputAction.next);

    final passwordField = fields[2];
    expect(passwordField.obscureText, isTrue);
    expect(passwordField.autocorrect, isFalse);
    expect(passwordField.enableSuggestions, isFalse);
    expect(passwordField.autofillHints, contains(AutofillHints.newPassword));
    expect(passwordField.textInputAction, TextInputAction.done);
  });

  testWidgets('short registration password is rejected without request', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpLoginPage(tester, repository);
    await switchToRegister(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '用户名'),
      'new-user',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), 'short');
    await tester.enterText(
      find.widgetWithText(TextFormField, '昵称'),
      'New User',
    );
    await tester.tap(find.text('注册并进入'));
    await tester.pump();

    expect(find.text('密码长度必须为 8～72 位'), findsOneWidget);
    expect(repository.registerCalls, 0);
  });

  testWidgets('empty login fields are rejected without request', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await pumpLoginPage(tester, repository);
    await tester.tap(find.text('登录'));
    await tester.pump();

    expect(find.text('用户名不能为空'), findsOneWidget);
    expect(find.text('密码不能为空'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('invalid credentials show credential error', (tester) async {
    final repository = FakeAuthRepository()
      ..loginError = const AppFailure(AppFailureType.invalidCredentials);
    await pumpLoginPage(tester, repository);
    await tester.enterText(find.widgetWithText(TextFormField, '用户名'), 'tester');
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'wrong-password',
    );
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('用户名或密码错误'), findsOneWidget);
  });

  testWidgets('username conflict shows registration error', (tester) async {
    final repository = FakeAuthRepository()
      ..registerError = const AppFailure(AppFailureType.usernameExists);
    await pumpLoginPage(tester, repository);
    await switchToRegister(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, '用户名'),
      'existing',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'password123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '昵称'),
      'Existing',
    );
    await tester.tap(find.text('注册并进入'));
    await tester.pumpAndSettle();

    expect(find.text('用户名已存在，请更换用户名'), findsOneWidget);
  });

  testWidgets('network and validation errors use different messages', (
    tester,
  ) async {
    final networkRepository = FakeAuthRepository()
      ..loginError = const AppFailure(AppFailureType.network);
    await pumpLoginPage(tester, networkRepository);
    await tester.enterText(find.widgetWithText(TextFormField, '用户名'), 'tester');
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'password123',
    );
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);

    final validationRepository = FakeAuthRepository()
      ..loginError = const AppFailure(AppFailureType.validation);
    await pumpLoginPage(tester, validationRepository);
    await tester.enterText(find.widgetWithText(TextFormField, '用户名'), 'tester');
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'password123',
    );
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.text('输入不符合要求，请检查后重试'), findsOneWidget);
  });
}
