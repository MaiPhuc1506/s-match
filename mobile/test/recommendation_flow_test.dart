import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/dev/presentation/dev_screen_explorer.dart';
import 'package:mobile/features/auth/widgets/profile_skill_radar.dart';
import 'package:mobile/features/court_map/screens/find_players_map_screen.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';
import 'package:mobile/features/recommendation/data/recommendation_fixtures.dart';
import 'package:mobile/features/recommendation/data/recommendation_repository.dart';
import 'package:mobile/features/recommendation/models/recommended_player.dart';
import 'package:mobile/features/recommendation/screens/recommendation_list_screen.dart';
import 'package:mobile/features/recommendation/screens/recommended_player_detail_screen.dart';
import 'package:mobile/features/recommendation/screens/no_recommendations_screen.dart';
import 'package:mobile/features/recommendation/widgets/recommendation_widgets.dart';

class _Repository extends RecommendationRepository {
  _Repository(this.load);
  final Future<List<RecommendedPlayer>> Function() load;
  @override
  Future<List<RecommendedPlayer>> search(RecommendationQuery query) => load();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final boundary = GlobalKey();
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    RecommendationRepository? repository,
    Size size = const Size(393, 852),
    double textScale = 1,
    EdgeInsets insets = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recommendationRepositoryProvider.overrideWithValue(
            repository ?? const FixtureRecommendationRepository(),
          ),
        ],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                padding: insets,
                viewPadding: insets,
              ),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_SPRINT7')) return;
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts();
      for (final element in find.byType(Image).evaluate()) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('/private/tmp/smatch-sprint7').create(recursive: true);
      await File('/private/tmp/smatch-sprint7/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Dev Explorer exposes all three Sprint 7 previews without login',
    (tester) async {
      await pump(tester, const DevScreenExplorer());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Recommendation');
      await tester.pumpAndSettle();
      for (final title in [
        'Recommendation List Screen',
        'Recommended Player Detail Screen',
        'No Recommendations Screen',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.tap(find.text('Recommendation List Screen'));
      await tester.pumpAndSettle();
      expect(
        find.text('UI preview · Based on your preferences'),
        findsOneWidget,
      );
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Recommended Player Detail Screen'));
      await tester.tap(find.text('Recommended Player Detail Screen'));
      await tester.pumpAndSettle();
      expect(find.text('94%'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('No Recommendations Screen'));
      await tester.tap(find.text('No Recommendations Screen'));
      await tester.pumpAndSettle();
      expect(find.text('No matching players\nright now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Find Players opens recommendations and Search Again returns to existing filters',
    (tester) async {
      await pump(tester, const FindPlayersMapScreen());
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        final top = tester
            .getTopLeft(find.byKey(const Key('players_sheet')))
            .dy;
        await tester.dragFrom(Offset(195, top + 10), const Offset(0, -180));
        await tester.pumpAndSettle();
      }
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
      await tester.tap(find.text('Find Matching Players'));
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationListScreen), findsOneWidget);
      await tester.tap(find.text('Search Again'));
      await tester.pumpAndSettle();
      expect(find.byType(FindPlayersMapScreen), findsOneWidget);
      expect(find.text('Player filters'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list opens selected profile, keeps Map active and Back restores list',
    (tester) async {
      await pump(tester, const RecommendationListScreen());
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(
        tester
            .widget<PlayerBottomNavigation>(find.byType(PlayerBottomNavigation))
            .currentTab,
        PlayerNavTab.map,
      );
      await capture(tester, 'list');
      await tester.tap(find.byType(RecommendationCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(RecommendedPlayerDetailScreen), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      final cta = tester.getRect(find.text('Invite to Match'));
      await capture(tester, 'detail');
      await tester.drag(
        find.byKey(const PageStorageKey('recommended_player_scroll')),
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSkillRadar), findsOneWidget);
      expect(tester.getRect(find.text('Invite to Match')), cta);
      expect(tester.takeException(), isNull);
      await capture(tester, 'detail_scrolled');
      await tester.tap(find.byTooltip('Back').last);
      await tester.pumpAndSettle();
      expect(find.byType(RecommendationListScreen), findsOneWidget);
    },
  );

  testWidgets(
    'loading then empty uses empty screen and Search Again callback',
    (tester) async {
      final request = Completer<List<RecommendedPlayer>>();
      var again = false;
      await pump(
        tester,
        RecommendationListScreen(onSearchAgain: () => again = true),
        repository: _Repository(() => request.future),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      request.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(NoRecommendationsScreen), findsOneWidget);
      await capture(tester, 'empty');
      await tester.tap(find.text('Search Again'));
      expect(again, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'API failure displays error and retry recovers without mock fallback',
    (tester) async {
      var count = 0;
      await pump(
        tester,
        const RecommendationListScreen(),
        repository: _Repository(() async {
          if (count++ == 0) {
            throw const RecommendationFailure('Service unavailable');
          }
          return referenceRecommendations;
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.text('94%'), findsNothing);
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('94%'), findsOneWidget);
    },
  );

  testWidgets(
    'all screens fit narrow phone with enlarged text and safe areas',
    (tester) async {
      for (final screen in [
        const RecommendationListScreen(),
        const NoRecommendationsScreen(),
        RecommendedPlayerDetailScreen(player: referenceRecommendations.first),
      ]) {
        await pump(
          tester,
          screen,
          size: const Size(320, 640),
          textScale: 1.4,
          insets: const EdgeInsets.only(top: 59, bottom: 34),
        );
        await tester.pumpAndSettle();
        final error = tester.takeException();
        expect(error, isNull, reason: screen.runtimeType.toString());
      }
    },
  );

  testWidgets(
    'real profile does not display fixture radar, photos, reasons or statistics',
    (tester) async {
      await pump(
        tester,
        const RecommendedPlayerDetailScreen(
          player: RecommendedPlayer(id: '7', score: 85),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Similar skill level (Intermediate)'), findsNothing);
      expect(find.byType(ProfileSkillRadar), findsNothing);
      await tester.tap(find.text('Invite to Match'));
      await tester.pumpAndSettle();
      expect(find.text('Open Matches'), findsOneWidget);
      expect(find.textContaining('not supported yet'), findsOneWidget);
    },
  );

  group('existing matchmaking API contract', () {
    late Dio dio;
    late List<RequestOptions> calls;
    setUp(() {
      calls = [];
      dio = Dio(BaseOptions(baseUrl: 'http://example.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls.add(options);
            final Object body = switch (options.path) {
              '/players/profile/me' => {
                'id': 1,
                'playerProfile': {'latitude': 16, 'longitude': 108},
              },
              '/availability/1/upcoming-slots' => ['2026-10-23T18:00:00Z'],
              '/matchmaking/recommend' => {
                'matchedUsers': [
                  {
                    'userId': '7',
                    'matchScore': 85.5,
                    'profile': {
                      'fullName': 'Real Player',
                      'nickname': 'Ranked Player',
                      'skillLevel': 'Intermediate',
                      'avatarUrl': 'https://example.test/avatar.png',
                    },
                  },
                ],
                'totalCandidatesProcessed': 1,
              },
              '/candidates/nearby' => {
                'candidates': [
                  {
                    'userId': 7,
                    'fullName': 'Outdated Nearby Name',
                    'skillLevel': 'Intermediate',
                    'distanceKm': 2.3,
                  },
                ],
              },
              _ => throw StateError('Unexpected endpoint ${options.path}'),
            };
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: body),
            );
          },
        ),
      );
    });

    test('uses saved criteria and returns server order/score without invented reasons', () async {
      final players = await ApiRecommendationRepository(dio)
          .search(const RecommendationQuery(distanceKm: 10));
      expect(players.single.score, 85.5);
      expect(players.single.name, 'Ranked Player');
      expect(players.single.level, 'Intermediate');
      expect(players.single.avatarUrl, 'https://example.test/avatar.png');
      expect(players.single.distanceKm, 2.3);
      expect(players.single.reasons, isEmpty);
      expect(players.single.hasReferenceRadar, isFalse);
      final payload =
          calls.firstWhere((r) => r.path == '/matchmaking/recommend').data
              as Map;
      expect(payload['location'], {'latitude': 16, 'longitude': 108});
      expect(payload['availableTimeSlots'], ['2026-10-23T18:00:00Z']);
      expect(payload['maxDistanceKm'], 10);
      expect(payload.containsKey('userId'), isFalse);
      expect(calls.any((r) => r.path.startsWith('/users/')), isFalse);
    });

    test('nearby outage does not hide ranked profile metadata', () async {
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/candidates/nearby') {
              h.reject(
                DioException(
                  requestOptions: o,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              h.next(o);
            }
          },
        ),
      );
      final players = await ApiRecommendationRepository(dio)
          .search(const RecommendationQuery());
      expect(players.single.name, 'Ranked Player');
      expect(players.single.avatarUrl, 'https://example.test/avatar.png');
      expect(players.single.distanceKm, isNull);
    });

    test('preserves server ranking, zero score and missing display fields without nearby fallback', () async {
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/matchmaking/recommend') {
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: {
                    'matchedUsers': [
                      {
                        'userId': '9',
                        'matchScore': 90,
                        'profile': {'fullName': 'Full Name', 'nickname': '  '},
                      },
                      {'userId': '7', 'matchScore': 0, 'profile': null},
                    ],
                  },
                ),
              );
            } else {
              h.next(o);
            }
          },
        ),
      );
      final players = await ApiRecommendationRepository(dio)
          .search(const RecommendationQuery());
      expect(players.map((p) => p.id), ['9', '7']);
      expect(players.first.name, 'Full Name');
      expect(players.last.score, 0);
      expect(players.last.displayName, 'Player #7');
      expect(players.last.avatarUrl, isNull);
      expect(players.last.level, isNull);
    });

    test('empty results skip optional nearby lookup', () async {
      dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/matchmaking/recommend') {
              h.resolve(
                Response(
                  requestOptions: o,
                  statusCode: 200,
                  data: {'matchedUsers': []},
                ),
              );
            } else {
              h.next(o);
            }
          },
        ),
      );
      expect(
        await ApiRecommendationRepository(dio)
            .search(const RecommendationQuery()),
        isEmpty,
      );
      expect(calls.any((r) => r.path == '/candidates/nearby'), isFalse);
    });

    for (final status in [401, 403, 503, 504]) {
      test('recommendation HTTP $status is an actionable failure', () async {
        dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (o, h) {
              if (o.path == '/matchmaking/recommend') {
                h.reject(
                  DioException(
                    requestOptions: o,
                    response: Response(requestOptions: o, statusCode: status),
                    type: DioExceptionType.badResponse,
                  ),
                );
              } else {
                h.next(o);
              }
            },
          ),
        );
        await expectLater(
          ApiRecommendationRepository(dio).search(const RecommendationQuery()),
          throwsA(isA<RecommendationFailure>()),
        );
      });
    }

    test('missing location is actionable error and does not make recommendation request', () async {
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            calls.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                data: {'id': 1, 'playerProfile': {}},
                statusCode: 200,
              ),
            );
          },
        ),
      );
      await expectLater(
        ApiRecommendationRepository(dio).search(const RecommendationQuery()),
        throwsA(isA<RecommendationFailure>()),
      );
      expect(calls.length, 1);
    });
  });
}
