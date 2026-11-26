import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main_dev.dart' as app;

/// Real Simulator journey against the local NestJS/PostgreSQL stack.
/// Run with:
///   flutter test integration_test/owner_dashboard_test.dart -d DEVICE_ID
///     --dart-define=DEV_OWNER_PASSWORD=LOCAL_DEV_PASSWORD
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Court Owner quick-login opens live dashboard with day value', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.text('Court Owner'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 6));

    expect(find.text('Your courts today'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text("Today's booked value"),
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
    await tester.pumpAndSettle();

    expect(find.text("Today's booked value"), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
