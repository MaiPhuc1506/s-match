import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/navigation/player_bottom_navigation.dart';
import 'package:mobile/features/feedback/screens/rating_history_screen.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';

void main() {
  Future<void> setPhoneViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('PlayerBottomNavigation widget specs', () {
    testWidgets(
      'renders all 5 tabs in exact order with correct assets and labels',
      (tester) async {
        await setPhoneViewport(tester);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: PlayerBottomNavigation(
                currentTab: PlayerNavTab.map,
              ),
            ),
          ),
        );

        // Verify all five labels exist
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('Match'), findsOneWidget);
        expect(find.text('Feedback'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);

        // Verify relative horizontal order: Home < Map < Match < Feedback < Profile
        final homeLeft = tester.getRect(find.text('Home')).left;
        final mapLeft = tester.getRect(find.text('Map')).left;
        final matchLeft = tester.getRect(find.text('Match')).left;
        final feedbackLeft = tester.getRect(find.text('Feedback')).left;
        final profileLeft = tester.getRect(find.text('Profile')).left;

        expect(homeLeft < mapLeft, isTrue);
        expect(mapLeft < matchLeft, isTrue);
        expect(matchLeft < feedbackLeft, isTrue);
        expect(feedbackLeft < profileLeft, isTrue);

        // Verify height is 84 on reference screen without safe-area inset
        final navSize = tester.getSize(find.byType(PlayerBottomNavigation));
        expect(navSize.height, equals(84.0));
        expect(navSize.width, equals(393.0));

        // Verify 5 SVG icons rendered with 22x22 dimension
        final svgFinders = find.byType(SvgPicture);
        expect(svgFinders, findsNWidgets(5));
        for (final element in svgFinders.evaluate()) {
          final svg = element.widget as SvgPicture;
          expect(svg.width, equals(22.0));
          expect(svg.height, equals(22.0));
        }
      },
    );

    testWidgets('active tab has color #05644F and inactive tabs have #7A8985', (
      tester,
    ) async {
      await setPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PlayerBottomNavigation(
              currentTab: PlayerNavTab.profile,
            ),
          ),
        ),
      );

      final profileText = tester.widget<Text>(find.text('Profile'));
      expect(profileText.style?.color, equals(const Color(0xFF05644F)));

      final mapText = tester.widget<Text>(find.text('Map'));
      expect(mapText.style?.color, equals(const Color(0xFF7A8985)));

      final homeText = tester.widget<Text>(find.text('Home'));
      expect(homeText.style?.color, equals(const Color(0xFF7A8985)));
    });

    testWidgets(
      'tapping currently active tab does nothing (no duplicate push or callback)',
      (tester) async {
        await setPhoneViewport(tester);
        bool tabChanged = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: PlayerBottomNavigation(
                currentTab: PlayerNavTab.match,
                onTapTab: (_) => tabChanged = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Match'));
        await tester.pumpAndSettle();

        expect(tabChanged, isFalse);
      },
    );

    testWidgets('Home reuses Profile and Feedback opens Sprint 8 history', (
      tester,
    ) async {
      await setPhoneViewport(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Content')),
            bottomNavigationBar: PlayerBottomNavigation(
              currentTab: PlayerNavTab.map,
            ),
          ),
        ),
      );

      // Tap Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerProfileScreen), findsOneWidget);

      // Tap Feedback
      await tester.tap(find.text('Feedback'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingHistoryScreen), findsOneWidget);
    });

    testWidgets('renders cleanly without overflow on narrow width 320', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PlayerBottomNavigation(
              currentTab: PlayerNavTab.map,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Match'), findsOneWidget);
      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });

  group('Player screens navigation bar integration', () {
    testWidgets(
      'PlayerProfileScreen contains PlayerBottomNavigation with Profile active',
      (tester) async {
        await setPhoneViewport(tester);

        await tester.pumpWidget(const MaterialApp(home: PlayerProfileScreen()));

        expect(find.byType(PlayerBottomNavigation), findsOneWidget);
        final nav = tester.widget<PlayerBottomNavigation>(
          find.byType(PlayerBottomNavigation),
        );
        expect(nav.currentTab, equals(PlayerNavTab.profile));
      },
    );

    testWidgets(
      'MatchListScreen contains PlayerBottomNavigation with Match active',
      (tester) async {
        await setPhoneViewport(tester);

        await tester.pumpWidget(const MaterialApp(home: MatchListScreen()));

        expect(find.byType(PlayerBottomNavigation), findsOneWidget);
        final nav = tester.widget<PlayerBottomNavigation>(
          find.byType(PlayerBottomNavigation),
        );
        expect(nav.currentTab, equals(PlayerNavTab.match));
      },
    );

    testWidgets(
      'FindCourtsMapScreen contains PlayerBottomNavigation with Map active',
      (tester) async {
        await setPhoneViewport(tester);

        await tester.pumpWidget(const MaterialApp(home: FindCourtsMapScreen()));

        expect(find.byType(PlayerBottomNavigation), findsOneWidget);
        final nav = tester.widget<PlayerBottomNavigation>(
          find.byType(PlayerBottomNavigation),
        );
        expect(nav.currentTab, equals(PlayerNavTab.map));
      },
    );

    testWidgets(
      'BookingHistoryScreen contains PlayerBottomNavigation with all 5 tabs',
      (tester) async {
        await setPhoneViewport(tester);

        await tester.pumpWidget(
          const MaterialApp(home: BookingHistoryScreen()),
        );

        expect(find.byType(PlayerBottomNavigation), findsOneWidget);
        final nav = tester.widget<PlayerBottomNavigation>(
          find.byType(PlayerBottomNavigation),
        );
        expect(nav.currentTab, isNull);
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Map'), findsOneWidget);
        expect(find.text('Match'), findsOneWidget);
        expect(find.text('Feedback'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      },
    );
  });
}
