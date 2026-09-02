// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:engineering_acceptance_app/core/network/api_client.dart';
import 'package:engineering_acceptance_app/core/session/session_storage.dart';
import 'package:engineering_acceptance_app/main.dart';
import 'package:engineering_acceptance_app/models/user.dart';

class EmptySessionStorage implements SessionStorage {
  StoredSession? value;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    value = null;
  }

  @override
  Future<StoredSession?> read() async => value;

  @override
  Future<void> write(StoredSession session) async => value = session;
}

void main() {
  testWidgets('application shows login form', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(sessionStorage: EmptySessionStorage()));
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('用户名'), findsOneWidget);
  });

  testWidgets('restored bearer session is cleared when profile returns 401', (
    tester,
  ) async {
    final storage = EmptySessionStorage()
      ..value = StoredSession(
        user: const User(id: 7, username: 'tester', nickname: 'Tester'),
        accessToken: 'rejected-token',
        expiresAt: DateTime.utc(2030),
      );
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"code":"AUTHENTICATION_REQUIRED","message":"login",'
          '"fieldErrors":{}}',
          401,
        ),
      ),
      baseUrl: 'http://example.test',
    );

    await tester.pumpWidget(MyApp(apiClient: client, sessionStorage: storage));
    await tester.pumpAndSettle();

    expect(find.text('登录已失效，请重新登录'), findsOneWidget);
    expect(storage.value, isNull);
    expect(storage.clearCalls, 1);
  });

  testWidgets('legacy session restores UI and explicit logout clears it', (
    tester,
  ) async {
    final storage = EmptySessionStorage()
      ..value = const StoredSession(
        user: User(id: 7, username: 'legacy', nickname: 'Legacy'),
      );
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '[]',
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
      baseUrl: 'http://example.test',
    );

    await tester.pumpWidget(MyApp(apiClient: client, sessionStorage: storage));
    await tester.pumpAndSettle();
    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('Legacy'), findsWidgets);

    await tester.tap(find.byTooltip('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('登录'), findsOneWidget);
    expect(storage.value, isNull);
  });

  testWidgets('legacy session is cleared after secured profile rejects it', (
    tester,
  ) async {
    final storage = EmptySessionStorage()
      ..value = const StoredSession(
        user: User(id: 7, username: 'legacy', nickname: 'Legacy'),
      );
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET' && request.url.path == '/api/posts') {
          return http.Response('[]', 200);
        }
        return http.Response(
          '{"code":"AUTHENTICATION_REQUIRED","message":"login",'
          '"fieldErrors":{}}',
          401,
        );
      }),
      baseUrl: 'http://example.test',
    );

    await tester.pumpWidget(MyApp(apiClient: client, sessionStorage: storage));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '昵称'),
      'Legacy edited',
    );
    await tester.scrollUntilVisible(
      find.text('保存资料'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('保存资料'));
    await tester.pumpAndSettle();

    expect(find.text('登录已失效，请重新登录'), findsOneWidget);
    expect(storage.value, isNull);
  });
}
