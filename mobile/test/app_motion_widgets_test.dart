import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_motion_widgets.dart';

void main() {
  testWidgets('section moves into place and does not replay on rebuild', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) {
            rebuild = update;
            return const Scaffold(
              body: AppReveal(
                child: SizedBox(key: Key('section'), width: 100, height: 100),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    final beginning = tester.getTopLeft(find.byKey(const Key('section'))).dy;
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getTopLeft(find.byKey(const Key('section'))).dy,
      lessThan(beginning),
    );
    await tester.pumpAndSettle();
    final ending = tester.getTopLeft(find.byKey(const Key('section'))).dy;
    expect(beginning - ending, closeTo(24, .1));
    rebuild(() {});
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const Key('section'))).dy, ending);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('offscreen section reveals once after scrolling into view', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 800),
                AppReveal(
                  id: 'lower-section',
                  child: SizedBox(key: Key('lower'), height: 120),
                ),
                SizedBox(height: 500),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Opacity opacity() => tester.widget<Opacity>(
      find
          .descendant(
            of: find.byType(AppReveal),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity().opacity, 0);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    expect(opacity().opacity, 1);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 650));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -650),
    );
    await tester.pump();
    expect(opacity().opacity, 1);
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced motion ($accessible) uses final geometry immediately',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: const Scaffold(
                body: AppReveal(delay: 270, child: SizedBox(height: 80)),
              ),
            ),
          ),
        );
        final opacity = tester.widget<Opacity>(
          find
              .descendant(
                of: find.byType(AppReveal),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(opacity.opacity, 1);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  }

  testWidgets('press feedback preserves the original tap and cancellation', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPressFeedback(
            child: ElevatedButton(
              onPressed: () => calls++,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Continue')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      .985,
    );
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('staggered forms preserve Flexible parent data and layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStaggeredColumn(
            children: [Text('Header'), Spacer(), Text('Save')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('Save')).dy,
      greaterThan(tester.getTopLeft(find.text('Header')).dy),
    );
  });
}
