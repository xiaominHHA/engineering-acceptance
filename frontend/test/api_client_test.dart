import 'package:engineering_acceptance_app/core/network/api_client.dart';
import 'package:engineering_acceptance_app/core/network/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('decodes a successful JSON response', () async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response('{"value":"ok"}', 200)),
      baseUrl: 'http://example.test',
    );

    final response = await client.get('/success') as Map<String, dynamic>;

    expect(response['value'], 'ok');
  });

  test('retains backend error contract for non-2xx response', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"code":"VALIDATION_FAILED","message":"invalid",'
          '"fieldErrors":{"username":"must not be blank"}}',
          400,
        ),
      ),
      baseUrl: 'http://example.test',
    );

    await expectLater(
      client.post('/users', const {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having((error) => error.code, 'code', 'VALIDATION_FAILED')
            .having(
              (error) => error.fieldErrors['username'],
              'field error',
              'must not be blank',
            ),
      ),
    );
  });

  test('maps client and timeout failures to network exceptions', () async {
    final networkClient = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
      baseUrl: 'http://example.test',
    );
    await expectLater(
      networkClient.get('/network'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiExceptionKind.network,
        ),
      ),
    );

    final timeoutClient = ApiClient(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
      baseUrl: 'http://example.test',
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timeoutClient.get('/timeout'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiExceptionKind.network,
        ),
      ),
    );
  });

  test(
    'adds and clears an in-memory bearer token without logging it',
    () async {
      final authorizations = <String?>[];
      final client = ApiClient(
        client: MockClient((request) async {
          authorizations.add(request.headers['authorization']);
          return http.Response('{}', 200);
        }),
        baseUrl: 'http://example.test',
      );

      client.useSession(userId: 7, accessToken: 'signed-token');
      await client.get('/authenticated');
      client.clearSession();
      await client.get('/public');

      expect(authorizations, ['Bearer signed-token', null]);
    },
  );
}
