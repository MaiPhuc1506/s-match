import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/feedback/screens/rating_history_screen.dart';
import 'package:mobile/main_dev.dart' as app;

/// Real Simulator feedback journey against the disposable completed match
/// created by feedback-setup.cjs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const matchTitle = String.fromEnvironment('QA_MATCH_TITLE');
  const p1Password = String.fromEnvironment('DEV_PLAYER_1_PASSWORD');

  testWidgets('player rates a teammate from rating history', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final result = await AuthService.instance.login(
      email: 'player@smatch.dev',
      password: p1Password,
    );
    expect(result.isSuccess, isTrue, reason: result.errorMessage);
    app.DevTestingHubApp.navKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RatingHistoryScreen()),
      (_) => false,
    );
    await tester.pumpAndSettle(const Duration(seconds: 6));

    final pending = find.text(matchTitle);
    expect(pending, findsOneWidget);
    await tester.tap(pending);
    await tester.pumpAndSettle(const Duration(seconds: 6));

    final rateButton = find.text('Rate Your Teammates');
    expect(rateButton, findsOneWidget);
    await tester.tap(rateButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final fiveStars = find.byTooltip('5 stars');
    expect(fiveStars, findsOneWidget);
    await tester.tap(fiveStars);
    await tester.pumpAndSettle();

    final submit = find.text('Submit Feedback');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle(const Duration(seconds: 8));

    expect(find.text('Feedback sent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
