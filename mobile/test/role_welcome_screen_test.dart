import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/player_welcome_screen.dart';
import 'package:mobile/features/auth/screens/court_owner_welcome_screen.dart';
import 'package:mobile/features/auth/screens/admin_welcome_screen.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/auth/widgets/role_welcome_layout.dart';
import 'package:mobile/features/facility/screens/facility_list_screen.dart';

class _NavigationObserver extends NavigatorObserver {
  final routes = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> size(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final role in WelcomeRole.values) {
    testWidgets(
      '$role matches the welcome composition and scrolls on compact screens',
      (tester) async {
        await size(tester, const Size(393, 852));
        var continued = false;
        await tester.pumpWidget(
          MaterialApp(
            home: RoleWelcomeLayout(
              role: role,
              onContinue: () => continued = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome to'), findsOneWidget);
        expect(find.text('S-Match'), findsOneWidget);
        await tester.ensureVisible(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        expect(continued, isTrue);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(320, 568);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(ElevatedButton)).bottom,
          lessThanOrEqualTo(568),
        );
        await tester.tap(find.text('Continue'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Player Continue opens the existing profile and Back returns', (
    tester,
  ) async {
    await size(tester, const Size(393, 852));
    await tester.pumpWidget(const MaterialApp(home: PlayerWelcomeScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerProfileScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(PlayerProfileScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerWelcomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Court Owner Continue preserves the Facility List route', (
    tester,
  ) async {
    await size(tester, const Size(393, 852));
    final observer = _NavigationObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const CourtOwnerWelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    final route = observer.routes.last as MaterialPageRoute;
    expect(
      route.builder(tester.element(find.byType(CourtOwnerWelcomeScreen))),
      isA<FacilityListScreen>(),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('Admin does not navigate into a different role workspace', (
    tester,
  ) async {
    await size(tester, const Size(393, 852));
    final observer = _NavigationObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const AdminWelcomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(observer.routes, hasLength(1));
    expect(find.byType(AdminWelcomeScreen), findsOneWidget);
  });
}
