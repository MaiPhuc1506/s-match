import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';

void main() {
  test(
    'link status uses authenticated session and reads server status',
    () async {
      final client = ApiClient.instance;
      client.setToken('fixture-token');
      addTearDown(client.clearToken);
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.path, '/auth/google/link');
          expect(options.headers['Authorization'], 'Bearer fixture-token');
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'linked': true},
            ),
          );
        },
      );
      client.dio.interceptors.add(interceptor);
      addTearDown(() => client.dio.interceptors.remove(interceptor));
      expect(await AuthService.instance.googleLinked(), isTrue);
    },
  );
  test('link status rejects missing session', () async {
    ApiClient.instance.clearToken();
    await expectLater(AuthService.instance.googleLinked(), throwsStateError);
  });
}
