import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/forgot_password_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('recovery uses request, verify and reset endpoints', (
    tester,
  ) async {
    final requests = <String>[];
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!options.path.startsWith('/auth/password-recovery/')) {
          return handler.next(options);
        }
        requests.add(options.path);
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 201,
            data: options.path.endsWith('/verify')
                ? {'resetToken': 'a' * 64}
                : {'message': 'ok'},
          ),
        );
      },
    );
    ApiClient.instance.dio.interceptors.add(interceptor);
    addTearDown(() => ApiClient.instance.dio.interceptors.remove(interceptor));
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
    expect(find.text('Enter the 6-digit verification code.'), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(ValueKey('otp-$i')), '123456'[i]);
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
    expect(find.text('Password updated'), findsOneWidget);
    expect(
      find.textContaining('Your password has been updated.'),
      findsOneWidget,
    );
    expect(requests, [
      '/auth/password-recovery/request',
      '/auth/password-recovery/verify',
      '/auth/password-recovery/reset',
    ]);
    await tester.pumpWidget(const SizedBox());
  });
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
