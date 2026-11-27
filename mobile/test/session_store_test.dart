import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/storage/session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('persists, rotates and clears only the refresh session', () async {
    const user = {'id': 3, 'email': 'player@smatch.dev', 'role': 'PLAYER'};
    expect(await SessionStore.instance.read(), isNull);

    await SessionStore.instance.save(refreshToken: 'refresh-1', user: user);
    final saved = await SessionStore.instance.read();
    expect(saved?.refreshToken, 'refresh-1');
    expect(saved?.user, user);

    await SessionStore.instance.updateRefreshToken('refresh-1', 'refresh-2');
    expect((await SessionStore.instance.read())?.refreshToken, 'refresh-2');
    expect((await SessionStore.instance.read())?.user, user);

    await SessionStore.instance.clear();
    expect(await SessionStore.instance.read(), isNull);
  });

  test('a late refresh from the previous user cannot replace the new session', () async {
    final store = SessionStore.instance;
    await store.save(refreshToken: 'old', user: {'id': 3});
    await Future.wait([
      store.clear(),
      store.save(refreshToken: 'new', user: {'id': 7}),
      store.updateRefreshToken('old', 'rotated-old'),
    ]);
    final saved = await store.read();
    expect(saved?.user['id'], 7);
    expect(saved?.refreshToken, 'new');
  });

  test('ignores corrupt stored payloads', () async {
    FlutterSecureStorage.setMockInitialValues({
      'smatch.session.v1': 'not-json',
    });
    expect(await SessionStore.instance.read(), isNull);
  });
}
