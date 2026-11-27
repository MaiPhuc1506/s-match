import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/dev/presentation/dev_testing_hub.dart';
import 'package:mobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:mobile/features/player_experience/screens/player_home_screen.dart';
import 'package:mobile/features/auth/screens/splash_screen.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/feedback/data/rating_api.dart';
import 'package:mobile/main_dev.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Dev Hub switches the four configured accounts in one tap', (
    tester,
  ) async {
    final client = ApiClient.instance;
    expect(Uri.parse(client.dio.options.baseUrl).host, 'localhost');
    app.main();
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> tap(Finder finder) async {
      final limit = DateTime.now().add(const Duration(seconds: 15));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(limit)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(finder.last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(finder.last);
      await tester.pump(const Duration(milliseconds: 500));
    }

    final startupDeadline = DateTime.now().add(const Duration(seconds: 20));
    while (find.byType(SplashScreen).evaluate().isNotEmpty &&
        DateTime.now().isBefore(startupDeadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    RatingApi? previousRatings;
    for (final (id, email, role) in [
      (3, 'player@smatch.dev', 'PLAYER'),
      (7, 'player2@smatch.dev', 'PLAYER'),
      (8, 'player3@smatch.dev', 'PLAYER'),
      (2, 'owner@smatch.dev', 'COURT_OWNER'),
      (3, 'player@smatch.dev', 'PLAYER'),
    ]) {
      debugPrint('Opening Dev Hub for test account $id');
      await tap(find.text('Dev Hub'));
      await tap(find.text('Quay lại Developer Testing Hub'));
      final action = switch (id) {
        3 => find.text('Player'),
        2 => find.text('Court Owner'),
        _ => find.descendant(
          of: find.widgetWithText(Card, email),
          matching: find.byTooltip('Đăng nhập'),
        ),
      };
      await tap(find.descendant(of: find.byType(DevTestingHub), matching: action).last);
      expect(find.byType(AlertDialog), findsNothing);
      final destination = find.byType(
        id == 2 ? DashboardScreen : PlayerHomeScreen,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (destination.evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(destination, findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(AuthService.instance.currentUser?['id'], id);
      expect(AuthService.instance.currentUser?['role'], role);
      final claims = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(client.token!.split('.')[1])),
        ),
      ) as Map;
      expect(claims['sub'], id);
      if (previousRatings != null) {
        expect(previousRatings.checkSession, throwsA(isA<RatingFailure>()));
      }
      previousRatings = RatingApi.current();
      if (id == 2) {
        final result = await client.dio.get<List<dynamic>>('/facilities/my');
        expect(result.data, isNotEmpty);
        expect(result.data!.every((row) => row['ownerId'] == id), isTrue);
      } else {
        final result = await client.dio.get<Map<String, dynamic>>(
          '/players/profile/me',
        );
        expect(result.data?['id'], id);
        expect(result.data?['email'], email);
        final profile = result.data!['playerProfile'] as Map;
        expect(profile['userId'], id);
        final skill = profile['skill'] as Map?;
        if (skill != null) expect(skill['playerProfileId'], profile['id']);
        final bookings = await client.dio.get<List<dynamic>>('/bookings/my');
        expect(bookings.data!.every((row) => row['userId'] == id), isTrue);
        final given = await client.dio.get<Map<String, dynamic>>(
          '/ratings/given',
        );
        expect(
          (given.data!['items'] as List).every((row) => row['raterId'] == id),
          isTrue,
        );
        await tap(find.text('Profile'));
        expect(find.text(result.data!['fullName'] as String), findsWidgets);
      }
      debugPrint('Simulator Quick Login verified: User $id ($role)');
    }
  }, skip: !const bool.fromEnvironment('RUN_DEV_QUICK_LOGIN_UAT'));
}
