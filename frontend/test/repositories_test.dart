import 'dart:convert';

import 'package:engineering_acceptance_app/core/error/app_failure.dart';
import 'package:engineering_acceptance_app/core/network/api_client.dart';
import 'package:engineering_acceptance_app/features/auth/auth_repository.dart';
import 'package:engineering_acceptance_app/features/forum/post_repository.dart';
import 'package:engineering_acceptance_app/features/profile/user_repository.dart';
import 'package:engineering_acceptance_app/models/post.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
      final repository = HttpAuthRepository(
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
    final repository = HttpAuthRepository(
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
    final authRepository = HttpAuthRepository(apiClient);
    final postRepository = HttpPostRepository(apiClient);

    await authRepository.login('legacy-user', 'password123');
    late final Post post;
    try {
      post = await postRepository.create('早上好', '吃早餐了吗');
    } on AppFailure catch (failure) {
      fail('Unexpected ${failure.type}: ${failure.message}');
    }

    expect(postBody, {'authorUserId': 7, 'title': '早上好', 'content': '吃早餐了吗'});
    expect(post.title, '早上好');
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
    final authRepository = HttpAuthRepository(apiClient);
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

    HttpAuthRepository authWithStatus(int statusCode) => HttpAuthRepository(
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

    final postRepository = HttpPostRepository(
      ApiClient(
        client: MockClient((_) async => http.Response('{}', 500)),
        baseUrl: 'http://example.test',
      ),
    );
    await expectFailure(postRepository.list(), AppFailureType.server);
  });

  test('new error codes take priority over legacy status fallback', () async {
    final knownCodeRepository = HttpAuthRepository(
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

    final unknownCodeRepository = HttpAuthRepository(
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
}
