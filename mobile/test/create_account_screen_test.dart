import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/create_account_screen.dart';
import 'package:mobile/features/auth/widgets/role_card.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/auth/screens/player_welcome_screen.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'registration has two public roles and toggles password visibility',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Admin'), findsNothing);
      expect(find.byType(RoleCard), findsNWidgets(2));
      expect(
        tester.widgetList<RoleCard>(find.byType(RoleCard)).first.isSelected,
        isTrue,
      );
      await tester.tap(find.text('Court Owner'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<RoleCard>(find.byType(RoleCard)).last.isSelected,
        isTrue,
      );
      final password = find.byType(TextField).last;
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.tap(
        find.descendant(of: password, matching: find.byType(IconButton)),
      );
      await tester.pump();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
      // Flutter reports layout errors automatically.
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create Account').last);
      await tester.pumpAndSettle();
      // Flutter reports layout errors automatically.
    },
  );
  testWidgets(
    'registration replaces prior session with the new authenticated account',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final client = ApiClient.instance;
      client.setToken('previous-user');
      AuthService.instance.currentUser = {'id': 3, 'fullName': 'Previous'};
      final calls = <String>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options.path);
          final Object data = switch (options.path) {
            '/auth/register' => {
              'data': {
                'id': 78,
                'email': 'fresh@example.test',
                'fullName': 'Fresh',
                'role': 'Player',
              },
            },
            '/auth/login' => {
              'accessToken': 'new-user-token',
              'refreshToken': 'new-refresh-token',
              'user': {'id': 78, 'fullName': 'Fresh', 'role': 'PLAYER'},
            },
            _ => <String, dynamic>{},
          };
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: data),
          );
        },
      );
      client.dio.interceptors.add(interceptor);
      addTearDown(() {
        client.dio.interceptors.remove(interceptor);
        client.clearToken();
        AuthService.instance.currentUser = null;
      });
      await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'Fresh');
      await tester.enterText(
        find.byType(TextField).at(1),
        'fresh@example.test',
      );
      await tester.enterText(find.byType(TextField).at(2), 'valid-pass');
      await tester.ensureVisible(find.text('Create Account').last);
      await tester.tap(find.text('Create Account').last);
      await tester.pumpAndSettle();
      expect(
        calls,
        containsAllInOrder(['/auth/register', '/auth/logout', '/auth/login']),
      );
      expect(client.token, 'new-user-token');
      expect(AuthService.instance.currentUser?['id'], 78);
      expect(find.byType(PlayerWelcomeScreen), findsOneWidget);
    },
  );
  testWidgets('unauthenticated profile does not show sample player data', (
    tester,
  ) async {
    ApiClient.instance.clearToken();
    AuthService.instance.currentUser = null;
    await tester.pumpWidget(const MaterialApp(home: PlayerProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Phúc Mai'), findsNothing);
    expect(find.text('Intermediate'), findsNothing);
    expect(find.text('24'), findsNothing);
    expect(find.text('18'), findsNothing);
    expect(find.text('Offensive'), findsNothing);
    expect(find.text('Not assessed'), findsOneWidget);
    expect(find.text('No skill assessment recorded yet.'), findsOneWidget);
  });
  testWidgets('registration does not keep a mismatched login session', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final client = ApiClient.instance;
    client.clearToken();
    AuthService.instance.currentUser = null;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        final Object data = switch (options.path) {
          '/auth/register' => {
            'data': {'id': 78, 'role': 'Player'},
          },
          '/auth/login' => {
            'accessToken': 'wrong-user-token',
            'user': {'id': 3, 'role': 'PLAYER'},
          },
          _ => <String, dynamic>{},
        };
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data),
        );
      },
    );
    client.dio.interceptors.add(interceptor);
    addTearDown(() {
      client.dio.interceptors.remove(interceptor);
      client.clearToken();
      AuthService.instance.currentUser = null;
    });
    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'Fresh');
    await tester.enterText(find.byType(TextField).at(1), 'fresh@example.test');
    await tester.enterText(find.byType(TextField).at(2), 'valid-pass');
    await tester.ensureVisible(find.text('Create Account').last);
    await tester.tap(find.text('Create Account').last);
    await tester.pumpAndSettle();
    expect(client.token, isNull);
    expect(AuthService.instance.currentUser, isNull);
    expect(find.byType(PlayerWelcomeScreen), findsNothing);
  });
}
