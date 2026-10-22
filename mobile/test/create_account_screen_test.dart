import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/create_account_screen.dart';
import 'package:mobile/features/auth/widgets/role_card.dart';

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
}
