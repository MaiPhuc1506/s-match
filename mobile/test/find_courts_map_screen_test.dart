import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    VoidCallback? onFindPlayers,
    VoidCallback? onCourtPreview,
    VoidCallback? onNavigateProfile,
    VoidCallback? onNavigateMatch,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: FindCourtsMapScreen(
          onFindPlayers: onFindPlayers,
          onCourtPreview: onCourtPreview,
          onNavigateProfile: onNavigateProfile,
          onNavigateMatch: onNavigateMatch,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('FindCourtsMapScreen renders at 393 × 852 without overflow', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(FindCourtsMapScreen), findsOneWidget);
    expect(find.text('Find Courts'), findsOneWidget);
    expect(find.text('Find Players'), findsOneWidget);
    expect(find.text('Nearby Courts'), findsOneWidget);
    expect(find.text('3 courts'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
  });

  testWidgets('FindCourtsMapScreen renders at smaller screen 360 × 640 without overflow', (tester) async {
    await pumpScreen(tester, size: const Size(360, 640));

    expect(find.byType(FindCourtsMapScreen), findsOneWidget);
    expect(find.text('Find Courts'), findsOneWidget);
    expect(find.text('Nearby Courts'), findsOneWidget);
  });

  testWidgets('Initial state has selected Sky bubble; background tap dismisses it', (tester) async {
    await pumpScreen(tester);

    expect(find.text('1.3 km · \$'), findsOneWidget);

    // Tap map canvas background
    await tester.tapAt(const Offset(50, 200));
    await tester.pumpAndSettle();

    expect(find.text('1.3 km · \$'), findsNothing);
  });

  testWidgets('Search trigger opens search panel and close button dismisses it', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Search courts'), findsNothing);

    await tester.tap(find.byKey(const Key('find_courts_search_trigger')));
    await tester.pumpAndSettle();

    expect(find.text('Search courts'), findsOneWidget);
    expect(find.text('Court name or area'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Search courts'), findsNothing);
  });

  testWidgets('Filters panel supports distance, toggles, and apply button', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Filters'), findsNothing);

    await tester.tap(find.byKey(const Key('find_courts_filter_trigger')));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('3 km'), findsOneWidget);
    expect(find.text('5 km'), findsOneWidget);
    expect(find.text('10 km'), findsOneWidget);

    // Select 10 km
    await tester.tap(find.text('10 km'));
    await tester.pumpAndSettle();

    // Toggle availability
    await tester.tap(find.text('Open now').first);
    await tester.pumpAndSettle();

    // Toggle indoor
    await tester.tap(find.text('Indoor').first);
    await tester.pumpAndSettle();

    // Toggle price
    await tester.tap(find.text('\$').first);
    await tester.pumpAndSettle();

    // Apply filters
    await tester.tap(find.byKey(const Key('find_courts_apply_filters')));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsNothing);
  });

  testWidgets('Map layers panel switches between Standard and Court clusters', (tester) async {
    await pumpScreen(tester);

    expect(find.text('3'), findsNothing);

    // Open layers panel via key
    await tester.tap(find.byKey(const Key('find_courts_layers_button')));
    await tester.pumpAndSettle();

    expect(find.text('Map layers'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Court clusters'), findsOneWidget);

    // Select Court clusters
    await tester.tap(find.text('Court clusters'));
    await tester.pumpAndSettle();

    expect(find.text('Map layers'), findsNothing);
    expect(find.text('3'), findsOneWidget);

    // Tap cluster to ungroup
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
  });

  testWidgets('Nearby courts sheet expands to half-expanded and collapse button returns to collapsed', (tester) async {
    await pumpScreen(tester);

    expect(find.text('3 courts'), findsOneWidget);
    expect(find.text('VNB Court'), findsNothing);

    // Tap collapsed summary card
    await tester.tap(find.byKey(const Key('find_courts_sheet_summary')));
    await tester.pumpAndSettle();

    expect(find.text('3 courts'), findsNothing);
    expect(find.text('VNB Court'), findsOneWidget);

    // Scroll list to reveal third card
    await tester.drag(find.text('VNB Court'), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(find.text('Duy Tân Sport Center'), findsOneWidget);

    // Tap collapse button
    await tester.tap(find.byKey(const Key('find_courts_collapse_sheet')));
    await tester.pumpAndSettle();

    expect(find.text('3 courts'), findsOneWidget);
    expect(find.text('VNB Court'), findsNothing);
  });

  testWidgets('Bottom navigation item Match triggers navigation', (tester) async {
    bool matchNavigated = false;
    await pumpScreen(
      tester,
      onNavigateMatch: () => matchNavigated = true,
    );

    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();

    expect(matchNavigated, isTrue);
  });

  testWidgets('Bottom navigation item Profile triggers navigation', (tester) async {
    bool profileNavigated = false;
    await pumpScreen(
      tester,
      onNavigateProfile: () => profileNavigated = true,
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(profileNavigated, isTrue);
  });

  testWidgets('Current location button recenters map without error', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('find_courts_location_button')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(FindCourtsMapScreen), findsOneWidget);
  });
}
