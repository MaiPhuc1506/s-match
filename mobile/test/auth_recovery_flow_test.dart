import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'recovery preview validates email, code and password without claiming real reset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'player@example.com');
      await tester.tap(find.text('Send Code'));
      await tester.pumpAndSettle();
      expect(find.text('Verify Code'), findsOneWidget);
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(
        find.text('Use demo code 2846 to preview the next screen.'),
        findsOneWidget,
      );
      for (var i = 0; i < 4; i++) {
        await tester.enterText(find.byKey(ValueKey('otp-$i')), '2846'[i]);
      }
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Password'), findsOneWidget);
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Meet all password requirements'),
        findsOneWidget,
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Strong123!');
      await tester.enterText(fields.at(1), 'Strong123!');
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Preview complete'), findsOneWidget);
      expect(
        find.textContaining('Your real password has not changed.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('recovery layouts fit $size and keyboard', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final screen in <Widget>[
        const ForgotPasswordScreen(),
        const VerifyCodeScreen(),
        const CreateNewPasswordScreen(),
      ]) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TextField).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
