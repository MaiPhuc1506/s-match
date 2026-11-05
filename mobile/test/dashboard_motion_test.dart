import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/dashboard/widgets/dashboard_motion.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final role in DashboardRole.values) {
    testWidgets(
      '${role.name} remains interactive during entrance and refresh',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: DashboardScreen(role: role, preview: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.byKey(const ValueKey('dashboard-tab-3')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('dashboard-tab-0')));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, 400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'counter interpolates, preserves formatting and does not replay on rebuild',
    (tester) async {
      Widget app() => const MaterialApp(
        home: Scaffold(body: DashboardCount('24,850,000đ', style: TextStyle())),
      );
      await tester.pumpWidget(app());
      expect(find.text('0đ'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('0đ'), findsNothing);
      expect(find.text('24,850,000đ'), findsNothing);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('24,850,000đ'), findsOneWidget);
      await tester.pumpWidget(app());
      expect(find.text('24,850,000đ'), findsOneWidget);
    },
  );
  testWidgets('reduced motion shows final KPI immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: DashboardCount('76%', style: TextStyle()),
        ),
      ),
    );
    expect(find.text('76%'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
  testWidgets(
    'offscreen section waits for scrolling and reveals once per visit',
    (tester) async {
      final visit = DashboardMotionVisit();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 900),
                  DashboardReveal(
                    visit: visit,
                    id: 'lower',
                    child: const SizedBox(
                      height: 100,
                      child: Text('Lower section'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(visit.revealed, isEmpty);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(visit.revealed, contains('lower'));
      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(DashboardReveal),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 700),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    },
  );
}
