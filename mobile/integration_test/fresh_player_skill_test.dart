import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/main.dart' as app;

// Opt in against the local development API only. Creates one new QA player.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'registered player starts unassessed and retains the quiz after login',
    (tester) async {
      final frames = <FrameTiming>[];
      SchedulerBinding.instance.addTimingsCallback(frames.addAll);
      addTearDown(
        () => SchedulerBinding.instance.removeTimingsCallback(frames.addAll),
      );
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final email = 'capstone-ui-$stamp@example.test';
      final name = 'QA Player $stamp';
      final password = List.generate(
        24,
        (_) => Random.secure().nextInt(26) + 65,
      );
      final secret = String.fromCharCodes(password);
      await AuthService.instance.logout();
      app.main();

      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(finder, findsWidgets);
      }

      Future<void> tap(Finder finder) async {
        await waitFor(finder);
        await tester.ensureVisible(finder.last);
        await tester.pumpAndSettle();
        await tester.tap(finder.last);
        await tester.pumpAndSettle();
      }

      await tap(find.text('Register'));
      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(0), name);
      await tester.enterText(inputs.at(1), email);
      await tester.enterText(inputs.at(2), secret);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tap(find.text('Create Account'));
      await tap(find.text('Continue'));
      await tap(find.text('Profile'));
      await waitFor(find.text(name));
      expect(find.text('Not assessed'), findsOneWidget);
      final id = AuthService.instance.currentUser?['id'];
      expect(id, isA<int>());

      await tap(find.text('View details'));
      await tap(find.text('Start Initial Estimate'));
      for (var i = 0; i < 6; i++) {
        await tap(find.byType(DropdownButtonFormField<int>).at(i));
        await tap(find.text('Usually').hitTestable());
      }
      await tap(find.text('Save Initial Estimate'));
      await waitFor(find.text('Assessment recorded'));
      expect(find.textContaining('Initial Skill Estimate'), findsWidgets);
      await tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tap(find.byIcon(Icons.logout_rounded));
      await tap(find.widgetWithText(ElevatedButton, 'Đăng xuất'));
      await waitFor(find.text('Log In'));
      await tester.enterText(inputs.at(0), email);
      await tester.enterText(inputs.at(1), secret);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tap(find.text('Log In'));
      await tap(find.text('Continue'));
      await tap(find.text('Profile'));
      await waitFor(find.text(name));
      expect(AuthService.instance.currentUser?['id'], id);
      expect(find.textContaining('4.0/5'), findsWidgets);
      if (frames.isNotEmpty) {
        final build = frames.map((f) => f.buildDuration.inMicroseconds).toList()
          ..sort();
        final raster =
            frames.map((f) => f.rasterDuration.inMicroseconds).toList()..sort();
        final p90 = ((frames.length - 1) * .9).round();
        debugPrint(
          'Debug Simulator frames=${frames.length}, p90 build=${build[p90]}us raster=${raster[p90]}us',
        );
      }
      debugPrint('Verified registration, skill and relogin for QA User ID $id');
    },
    skip: !const bool.fromEnvironment('RUN_DEV_SIGNUP_UAT'),
  );
}
