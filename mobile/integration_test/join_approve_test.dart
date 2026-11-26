import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/screens/player_welcome_screen.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';
import 'package:mobile/main_dev.dart' as app;

/// Cross-account journey on the iOS Simulator against the live local stack.
/// QA_MODE=join  -> player2@smatch.dev requests to join match QA_MATCH_ID
/// QA_MODE=approve -> player@smatch.dev approves that pending request
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const matchId = int.fromEnvironment('QA_MATCH_ID');
  const mode = String.fromEnvironment('QA_MODE');
  const p1Password = String.fromEnvironment('DEV_PLAYER_1_PASSWORD');
  const p2Password = String.fromEnvironment('DEV_PLAYER_2_PASSWORD');

  Future<void> signIn(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    final result = await AuthService.instance.login(
      email: email,
      password: password,
    );
    expect(result.isSuccess, isTrue, reason: result.errorMessage);
    final navigator = app.DevTestingHubApp.navKey.currentState!;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PlayerWelcomeScreen()),
      (_) => false,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  Future<void> openMatchTab(WidgetTester tester) async {
    final nav = find.byType(PlayerBottomNavigation);
    await tester.tap(find.descendant(of: nav, matching: find.text('Match')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  testWidgets('player requests then host approves the same open match', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (mode == 'join') {
      await signIn(tester, 'player2@smatch.dev', p2Password);
      await openMatchTab(tester);
      final card = find.byKey(ValueKey('open-match-$matchId'));
      await tester.scrollUntilVisible(
        card,
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('Request to Join'), findsOneWidget);
      await tester.tap(find.text('Request to Join'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('Your status: REQUESTED'), findsOneWidget);
    } else if (mode == 'approve') {
      await signIn(tester, 'player@smatch.dev', p1Password);
      await openMatchTab(tester);
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      final card = find.byKey(ValueKey('open-match-$matchId'));
      await tester.scrollUntilVisible(
        card,
        220,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('Join requests'), findsOneWidget);
      await tester.tap(find.byTooltip('Accept'));
      await tester.pumpAndSettle(const Duration(seconds: 4));
      expect(find.text('2 / 4 players'), findsOneWidget);
    } else {
      fail('QA_MODE must be join or approve');
    }
    expect(tester.takeException(), isNull);
  });
}
