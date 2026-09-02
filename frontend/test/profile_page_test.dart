import 'dart:async';

import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/features/profile/profile_page.dart';
import 'package:engineering_acceptance_app/features/profile/profile_view_model.dart';
import 'package:engineering_acceptance_app/features/profile/user_repository.dart';
import 'package:engineering_acceptance_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const initialUser = User(
  id: 1,
  username: 'profile-tester',
  nickname: 'Before',
  birthday: '2000-01-02',
  school: 'Old School',
  className: 'Old Class',
);

class FakeUserRepository implements UserRepository {
  final updates = <String>[];
  Completer<User>? controlledUpdate;
  Object? error;
  String? lastBirthday;

  @override
  Future<User> get(int userId) async => initialUser;

  @override
  Future<User> update(
    int userId, {
    required String nickname,
    String? birthday,
    String? school,
    String? className,
  }) async {
    updates.add(nickname);
    lastBirthday = birthday;
    if (error case final value?) throw value;
    final completer = controlledUpdate;
    if (completer != null) return completer.future;
    return User(
      id: userId,
      username: initialUser.username,
      nickname: nickname,
      birthday: birthday,
      school: school,
      className: className,
    );
  }
}

Future<ProfileViewModel> pumpProfile(
  WidgetTester tester,
  FakeUserRepository repository, {
  Future<void> Function(User)? onUpdate,
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final viewModel = ProfileViewModel(repository, initialUser);
  addTearDown(viewModel.dispose);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: ProfilePage(
          viewModel: viewModel,
          onUpdate: onUpdate ?? (_) async {},
        ),
      ),
    ),
  );
  return viewModel;
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapSave(WidgetTester tester) async {
  final button = find.text('保存资料');
  await tester.scrollUntilVisible(
    button,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(button);
}

void main() {
  testWidgets('save is enabled only after profile fields change', (
    tester,
  ) async {
    await pumpProfile(tester, FakeUserRepository());
    await tester.scrollUntilVisible(
      find.text('保存资料'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.enterText(field('昵称'), 'Changed');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('validates nickname empty and over max, accepts max boundary', (
    tester,
  ) async {
    final repository = FakeUserRepository();
    await pumpProfile(tester, repository);

    await tester.enterText(field('昵称'), '');
    await tapSave(tester);
    await tester.pump();
    expect(find.text('昵称不能为空'), findsOneWidget);

    await tester.enterText(field('昵称'), 'a' * 101);
    await tapSave(tester);
    await tester.pump();
    expect(find.text('昵称不能超过 100 位'), findsOneWidget);
    expect(repository.updates, isEmpty);

    await tester.enterText(field('昵称'), 'a' * 100);
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(repository.updates, ['a' * 100]);
  });

  testWidgets('date picker submits the backend LocalDate format', (
    tester,
  ) async {
    final repository = FakeUserRepository();
    await pumpProfile(tester, repository);

    expect(find.text('2000年1月2日'), findsOneWidget);
    await tester.tap(find.byKey(const Key('birthday-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tapSave(tester);
    await tester.pumpAndSettle();

    expect(repository.lastBirthday, '2000-01-15');
  });

  testWidgets('saving disables button and shows progress', (tester) async {
    final repository = FakeUserRepository()
      ..controlledUpdate = Completer<User>();
    await pumpProfile(tester, repository);
    await tester.enterText(field('昵称'), 'Saving');
    await tapSave(tester);
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.controlledUpdate!.complete(initialUser);
    await tester.pumpAndSettle();
  });

  testWidgets('save failure retains edits and allows retry', (tester) async {
    final repository = FakeUserRepository()
      ..error = const AppFailure(AppFailureType.network);
    await pumpProfile(tester, repository);
    await tester.enterText(field('昵称'), 'Keep this edit');
    await tapSave(tester);
    await tester.pumpAndSettle();
    expect(find.text('无法连接服务器，请检查网络后重试'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(field('昵称')).controller?.text,
      'Keep this edit',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('success reports saved and updates user state', (tester) async {
    final repository = FakeUserRepository();
    User? updatedUser;
    final viewModel = await pumpProfile(
      tester,
      repository,
      onUpdate: (user) async {
        updatedUser = user;
      },
    );
    await tester.enterText(field('昵称'), 'After');
    await tapSave(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('已保存'), findsOneWidget);
    expect(updatedUser?.nickname, 'After');
    expect(viewModel.user.nickname, 'After');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('small viewport and large text render without exceptions', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      FakeUserRepository(),
      size: const Size(320, 480),
      textScale: 2,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('保存资料'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('保存资料'), findsOneWidget);
  });
}
