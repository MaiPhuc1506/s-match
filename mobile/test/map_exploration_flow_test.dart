import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/screens/court_preview_screen.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/court_map/screens/find_players_map_screen.dart';

void main() {
  final boundary = GlobalKey();
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(393, 852),
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: RepaintBoundary(key: boundary, child: screen),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets(
    'Court Preview fits two sizes and View Courts invokes its destination',
    (tester) async {
      var opened = false;
      await pump(tester, CourtPreviewScreen(onViewCourts: () => opened = true));
      expect(find.text('Sky Badminton'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('view_courts')));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('court_preview_scroll')),
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(find.text('Court Information'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'favorite persists and gallery responds to swipes with supplied images',
    (tester) async {
      await pump(
        tester,
        const CourtPreviewScreen(),
        overrides: [
          courtPreviewProvider.overrideWith(
            (ref) async => const CourtPreviewData(
              photos: [
                'assets/images/match/facility_court.jpg',
                'assets/images/match/facility_court.jpg',
              ],
            ),
          ),
        ],
      );
      await tester.tap(find.bySemanticsLabel('Favorite court'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CourtPreviewScreen)),
      );
      expect(container.read(courtFavoriteProvider), isTrue);
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
    },
  );

  testWidgets(
    'Players search filters real local results and supports empty state',
    (tester) async {
      await pump(tester, const FindPlayersMapScreen());
      expect(find.text('Minh Quân'), findsOneWidget);
      expect(find.text('Thảo Vy'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(
        find.text('No nearby players match your filters.'),
        findsOneWidget,
      );
      expect(find.text('Minh Quân'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Minh');
      await tester.pump(const Duration(milliseconds: 260));
      await tester.pumpAndSettle();
      expect(find.text('Minh Quân'), findsOneWidget);
      expect(find.text('Thảo Vy'), findsNothing);
    },
  );

  testWidgets('Player row opens public demo preview with a Back action', (
    tester,
  ) async {
    await pump(tester, const FindPlayersMapScreen());
    await tester.tap(find.byKey(const ValueKey('player_minh')));
    await tester.pumpAndSettle();
    expect(find.text('Player preview'), findsOneWidget);
    expect(
      find.text('Demo profile · Approximate location only'),
      findsOneWidget,
    );
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Player preview'), findsNothing);
  });

  testWidgets('Players sheet expands and zoomed camera recenters', (
    tester,
  ) async {
    await pump(tester, const FindPlayersMapScreen());
    final initial = tester
        .getTopLeft(find.byKey(const Key('players_sheet')))
        .dy;
    await tester.dragFrom(Offset(195, initial + 10), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('players_sheet'))).dy,
      lessThan(initial),
    );
    await tester.dragFrom(
      Offset(
        195,
        tester.getTopLeft(find.byKey(const Key('players_sheet'))).dy + 10,
      ),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Find Matching Players'),
      80,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('players_sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Find Matching Players'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final map = tester.widget<InteractiveViewer>(
      find.byKey(const Key('players_map')),
    );
    map.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.tap(find.bySemanticsLabel('Recenter'));
    await tester.pumpAndSettle();
    expect(
      map.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(1, .001),
    );
    await tester.binding.setSurfaceSize(const Size(360, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Modes return to the same Courts instance and its selected marker',
    (tester) async {
      await pump(tester, const FindCourtsMapScreen());
      final originalState = tester.state(find.byType(FindCourtsMapScreen));
      await tester.tap(find.text('Find Players'));
      await tester.pumpAndSettle();
      expect(find.byType(FindPlayersMapScreen), findsOneWidget);
      await tester.tap(find.text('Find Courts').last);
      await tester.pumpAndSettle();
      expect(
        tester.state(find.byType(FindCourtsMapScreen)),
        same(originalState),
      );
      expect(find.text('1.3 km · \$'), findsOneWidget);
    },
  );

  testWidgets('Players loading, permission error and retry states', (
    tester,
  ) async {
    final gate = Completer<List<NearbyPlayer>>();
    var attempts = 0;
    await pump(
      tester,
      const FindPlayersMapScreen(),
      settle: false,
      overrides: [
        nearbyPlayersProvider.overrideWith((ref) {
          attempts++;
          return attempts == 1 ? gate.future : Future.value(demoPlayers);
        }),
      ],
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.completeError(const ExplorationPermissionDenied());
    await tester.pumpAndSettle();
    expect(find.textContaining('Location access denied.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Minh Quân'), findsOneWidget);
  });
  testWidgets('Player filters change the local result set', (tester) async {
    await pump(tester, const FindPlayersMapScreen());
    await tester.tap(find.bySemanticsLabel('Player filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Beginner'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(find.text('Minh Quân'), findsNothing);
    expect(find.text('Thảo Vy'), findsOneWidget);
  });

  testWidgets('Player camera survives a round trip through Courts mode', (
    tester,
  ) async {
    await pump(tester, const FindPlayersMapScreen());
    final map = tester.widget<InteractiveViewer>(
      find.byKey(const Key('players_map')),
    );
    map.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    map.onInteractionEnd!(ScaleEndDetails());
    await tester.tap(find.text('Find Courts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find Players'));
    await tester.pumpAndSettle();
    final restored = tester.widget<InteractiveViewer>(
      find.byKey(const Key('players_map')),
    );
    expect(
      restored.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(2, .001),
    );
  });

  testWidgets(
    'Share action sends the current court summary to the native share plugin',
    (tester) async {
      final calls = <MethodCall>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'com.apple.UIKit.activity.CopyToPasteboard';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await pump(tester, const CourtPreviewScreen());
      await tester.tap(find.bySemanticsLabel('Share court'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(
        (calls.single.arguments as Map)['text'],
        contains('Sky Badminton'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
