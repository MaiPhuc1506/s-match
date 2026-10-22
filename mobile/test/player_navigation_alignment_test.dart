import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/court_map/screens/find_players_map_screen.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';
import 'package:mobile/features/recommendation/data/recommendation_fixtures.dart';
import 'package:mobile/features/recommendation/data/recommendation_repository.dart';
import 'package:mobile/features/recommendation/screens/no_recommendations_screen.dart';
import 'package:mobile/features/recommendation/screens/recommendation_list_screen.dart';
import 'package:mobile/features/recommendation/screens/recommended_player_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  for (final scenario in [
    (const Size(393, 852), const EdgeInsets.only(top: 59, bottom: 34)),
    (const Size(430, 932), const EdgeInsets.only(top: 62, bottom: 34)),
    (const Size(393, 852), EdgeInsets.zero),
  ]) {
    testWidgets(
      'Player bars and all five icons align across screens at ${scenario.$1}, inset ${scenario.$2.bottom}',
      (tester) async {
        final size = scenario.$1;
        final insets = scenario.$2;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        Rect? referenceBar;
        List<Rect>? referenceIcons;
        for (final screen in [
          const RecommendationListScreen(),
          RecommendedPlayerDetailScreen(player: referenceRecommendations.first),
          const NoRecommendationsScreen(),
          const MatchListScreen(),
          const FindCourtsMapScreen(),
          const FindPlayersMapScreen(),
          const PlayerProfileScreen(),
          const BookingHistoryScreen(),
        ]) {
          // Recreate the root so no previous route or screen state affects geometry.
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                recommendationRepositoryProvider.overrideWithValue(
                  const FixtureRecommendationRepository(),
                ),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(padding: insets, viewPadding: insets),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final nav = find.byType(PlayerBottomNavigation);
          expect(nav, findsOneWidget);
          final rect = tester.getRect(nav);
          expect(
            rect.bottom,
            size.height,
            reason: '${screen.runtimeType}: bar must touch screen bottom',
          );
          expect(
            rect.width,
            size.width,
            reason: '${screen.runtimeType}: full-width bar',
          );
          referenceBar ??= rect;
          expect(
            rect,
            referenceBar,
            reason: '${screen.runtimeType}: identical safe-area handling',
          );
          final icons = find.descendant(
            of: nav,
            matching: find.byType(SvgPicture),
          );
          final bounds = [
            for (var i = 0; i < 5; i++) tester.getRect(icons.at(i)),
          ];
          referenceIcons ??= bounds;
          expect(
            bounds,
            referenceIcons,
            reason: '${screen.runtimeType}: identical icon baseline',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: screen.runtimeType.toString(),
          );
        }
      },
    );
  }
}
