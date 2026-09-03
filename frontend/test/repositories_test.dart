import 'dart:convert';

import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/core/network/api_client.dart';
import 'package:engineering_acceptance_app/core/session/session_storage.dart';
import 'package:engineering_acceptance_app/features/auth/auth_repository.dart';
import 'package:engineering_acceptance_app/features/forum/forum_repository.dart';
import 'package:engineering_acceptance_app/features/profile/user_repository.dart';
import 'package:engineering_acceptance_app/models/post.dart';
import 'package:engineering_acceptance_app/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemorySessionStorage implements SessionStorage {
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

HttpAuthRepository createAuthRepository(
  ApiClient client, {
  MemorySessionStorage? storage,
}) => HttpAuthRepository(
  client,
  sessionStorage: storage ?? MemorySessionStorage(),
);

void main() {
  test('auth repository maps backend error codes to typed failures', () async {
    final cases = <String, AppFailureType>{
      'USERNAME_EXISTS': AppFailureType.usernameExists,
      'INVALID_CREDENTIALS': AppFailureType.invalidCredentials,
      'VALIDATION_FAILED': AppFailureType.validation,
      'INTERNAL_ERROR': AppFailureType.server,
      'UNRECOGNIZED_CODE': AppFailureType.unknown,
    };

    for (final entry in cases.entries) {
      final repository = createAuthRepository(
        ApiClient(
          client: MockClient(
            (_) async => http.Response(
              '{"code":"${entry.key}","message":"error",'
              '"fieldErrors":{}}',
              entry.key == 'INTERNAL_ERROR' ? 500 : 400,
            ),
          ),
          baseUrl: 'http://example.test',
        ),
      );

      await expectLater(
        repository.login('tester', 'password123'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.type,
            entry.key,
            entry.value,
          ),
        ),
      );
    }
  });

  test('auth repository maps a successful response to User', () async {
    final repository = createAuthRepository(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"tokenType":"Bearer","accessToken":"signed-token",'
            '"expiresAt":"2030-01-01T00:00:00Z",'
            '"user":{"id":7,"username":"tester","nickname":"Tester"}}',
            200,
          ),
        ),
        baseUrl: 'http://example.test',
      ),
    );

    final user = await repository.login('tester', 'password123');

    expect(user.id, 7);
    expect(user.username, 'tester');
  });

  test('post request remains compatible with the v1.0.10 contract', () async {
    Map<String, dynamic>? postBody;
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          // v1.0.10 returned a flat user and no bearer token.
          return http.Response(
            '{"id":7,"username":"legacy-user","nickname":"Legacy"}',
            200,
          );
        }
        postBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response(
          '{"id":"post-1","authorUserId":7,'
          '"title":"早上好","content":"吃早餐了吗"}',
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'http://example.test',
    );
    final authRepository = createAuthRepository(apiClient);
    final postRepository = HttpForumRepository(apiClient);

    await authRepository.login('legacy-user', 'password123');
    late final Post post;
    try {
      post = await postRepository.createPost('早上好', '吃早餐了吗');
    } on AppFailure catch (failure) {
      fail('Unexpected ${failure.type}: ${failure.message}');
    }

    expect(postBody, {'authorUserId': 7, 'title': '早上好', 'content': '吃早餐了吗'});
    expect(post.title, '早上好');
    expect(post.authorNickname, isNull);
  });

  test('authenticated repositories send the in-memory bearer token', () async {
    String? authorization;
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            '{"accessToken":"signed-token",'
            '"user":{"id":7,"username":"tester","nickname":"Tester"}}',
            200,
          );
        }
        authorization = request.headers['authorization'];
        return http.Response(
          '{"id":7,"username":"tester","nickname":"Updated"}',
          200,
        );
      }),
      baseUrl: 'http://example.test',
    );
    final authRepository = createAuthRepository(apiClient);
    final userRepository = HttpUserRepository(apiClient);

    await authRepository.login('tester', 'password123');
    await userRepository.update(7, nickname: 'Updated');

    expect(authorization, 'Bearer signed-token');
  });

  test('repositories map legacy responses without an error code', () async {
    Future<void> expectFailure(
      Future<Object?> request,
      AppFailureType expected,
    ) async {
      await expectLater(
        request,
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.type,
            'failure type',
            expected,
          ),
        ),
      );
    }

    HttpAuthRepository authWithStatus(int statusCode) => createAuthRepository(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"status":$statusCode,"error":"Legacy Spring error"}',
            statusCode,
          ),
        ),
        baseUrl: 'http://example.test',
      ),
    );

    await expectFailure(
      authWithStatus(401).login('tester', 'wrong-password'),
      AppFailureType.invalidCredentials,
    );
    await expectFailure(
      authWithStatus(409).register('tester', 'password123', 'Tester'),
      AppFailureType.usernameExists,
    );
    await expectFailure(
      authWithStatus(400).login('tester', 'password123'),
      AppFailureType.validation,
    );

    final userRepository = HttpUserRepository(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 404)),
        baseUrl: 'http://example.test',
      ),
    );
    await expectFailure(
      userRepository.update(99, nickname: 'Missing'),
      AppFailureType.notFound,
    );

    final postRepository = HttpForumRepository(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 500)),
        baseUrl: 'http://example.test',
      ),
    );
    await expectFailure(
      postRepository.listPosts(page: 0),
      AppFailureType.server,
    );
  });

  test('new error codes take priority over legacy status fallback', () async {
    final knownCodeRepository = createAuthRepository(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"VALIDATION_FAILED","message":"invalid",'
            '"fieldErrors":{}}',
            401,
          ),
        ),
        baseUrl: 'http://example.test',
      ),
    );
    await expectLater(
      knownCodeRepository.login('tester', 'password123'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.type,
          'known code type',
          AppFailureType.validation,
        ),
      ),
    );

    final unknownCodeRepository = createAuthRepository(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"FUTURE_CONFLICT","message":"conflict",'
            '"fieldErrors":{}}',
            409,
          ),
        ),
        baseUrl: 'http://example.test',
      ),
    );
    await expectLater(
      unknownCodeRepository.register('tester', 'password123', 'Tester'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.type,
          'unknown code type',
          AppFailureType.unknown,
        ),
      ),
    );
  });

  test('protected repository maps token rejection to sessionExpired', () async {
    final repository = HttpUserRepository(
      ApiClient(
        client: MockClient(
          (_) async => http.Response(
            '{"code":"AUTHENTICATION_REQUIRED",'
            '"message":"Authentication is required","fieldErrors":{}}',
            401,
          ),
        ),
        baseUrl: 'http://example.test',
      ),
    );

    await expectLater(
      repository.update(7, nickname: 'Updated'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.type,
          'failure type',
          AppFailureType.sessionExpired,
        ),
      ),
    );
  });

  test(
    'post repository parses nickname and maps delete compatibility',
    () async {
      final nicknameRepository = HttpForumRepository(
        ApiClient(
          client: MockClient(
            (_) async => http.Response(
              '[{"id":"post-1","authorUserId":7,"authorNickname":"真实昵称",'
              '"title":"Title","content":"Content"}]',
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            ),
          ),
          baseUrl: 'http://example.test',
        ),
      );
      expect(
        (await nicknameRepository.listPosts(page: 0)).single.authorNickname,
        '真实昵称',
      );

      for (final status in [404, 405]) {
        final legacyRepository = HttpForumRepository(
          ApiClient(
            client: MockClient((_) async => http.Response('{}', status)),
            baseUrl: 'http://example.test',
          ),
        );
        await expectLater(
          legacyRepository.deletePost('post-1'),
          throwsA(
            isA<AppFailure>().having(
              (failure) => failure.type,
              'legacy delete type',
              AppFailureType.featureUnavailable,
            ),
          ),
        );
      }

      final currentRepository = HttpForumRepository(
        ApiClient(
          client: MockClient(
            (_) async => http.Response(
              '{"code":"POST_NOT_FOUND","message":"missing",'
              '"fieldErrors":{}}',
              404,
            ),
          ),
          baseUrl: 'http://example.test',
        ),
      );
      await expectLater(
        currentRepository.deletePost('post-1'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.type,
            'current delete type',
            AppFailureType.notFound,
          ),
        ),
      );
    },
  );

  test('new bearer session is saved and restored with expiry', () async {
    final storage = MemorySessionStorage();
    final loginClient = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"accessToken":"signed-token","expiresAt":"2030-01-01T00:00:00Z",'
          '"user":{"id":7,"username":"tester","nickname":"Tester"}}',
          200,
        ),
      ),
      baseUrl: 'http://example.test',
    );
    await createAuthRepository(
      loginClient,
      storage: storage,
    ).login('tester', 'password123');

    expect(storage.value?.accessToken, 'signed-token');
    expect(storage.value?.expiresAt, DateTime.utc(2030));

    String? authorization;
    final restoredClient = ApiClient(
      client: MockClient((request) async {
        authorization = request.headers['authorization'];
        return http.Response(
          '{"id":7,"username":"tester","nickname":"Tester"}',
          200,
        );
      }),
      baseUrl: 'http://example.test',
    );
    final restored = await createAuthRepository(
      restoredClient,
      storage: storage,
    ).restoreSession();
    await HttpUserRepository(restoredClient).get(restored!.user.id);

    expect(restored.isLegacy, isFalse);
    expect(authorization, 'Bearer signed-token');
  });

  test('logout and expired bearer session clear persisted state', () async {
    final storage = MemorySessionStorage()
      ..value = StoredSession(
        user: const User(id: 7, username: 'tester', nickname: 'Tester'),
        accessToken: 'expired-token',
        expiresAt: DateTime.utc(2020),
      );
    final repository = createAuthRepository(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 500)),
        baseUrl: 'http://example.test',
      ),
      storage: storage,
    );

    await expectLater(
      repository.restoreSession(),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.type,
          'failure type',
          AppFailureType.sessionExpired,
        ),
      ),
    );
    expect(storage.value, isNull);

    storage.value = const StoredSession(
      user: User(id: 7, username: 'legacy', nickname: 'Legacy'),
    );
    final legacy = await repository.restoreSession();
    expect(legacy?.isLegacy, isTrue);
    await repository.logout();
    expect(storage.value, isNull);
  });

  test(
    'legacy session survives restart until secured API rejects it',
    () async {
      final storage = MemorySessionStorage()
        ..value = const StoredSession(
          user: User(id: 7, username: 'legacy', nickname: 'Legacy'),
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
      final auth = createAuthRepository(client, storage: storage);

      final restored = await auth.restoreSession();
      expect(restored?.isLegacy, isTrue);
      await expectLater(
        HttpUserRepository(client).update(7, nickname: 'Legacy'),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.type,
            'failure type',
            AppFailureType.sessionExpired,
          ),
        ),
      );
      await auth.logout();
      expect(storage.value, isNull);
    },
  );
}
