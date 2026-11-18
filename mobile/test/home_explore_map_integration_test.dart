import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/screens/court_preview_screen.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/court_map/widgets/court_maplibre_map.dart';
import 'package:mobile/features/player_experience/screens/courts_screens.dart';
import 'package:mobile/features/player_experience/screens/player_home_screen.dart';

import 'support/fake_court_map_platform.dart';

void main() {
  final originalPlatform = MapLibrePlatform.createInstance;
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => MapLibrePlatform.createInstance = FakeCourtMapPlatform.new);
  tearDown(() => MapLibrePlatform.createInstance = originalPlatform);

  final sampleApiFacilitiesJson = [
    {
      'id': 31,
      'ownerId': 2,
      'name': 'CLB Cầu Lông Hải Châu Live',
      'address': '88 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
      'latitude': 16.0605,
      'longitude': 108.2155,
      'contactPhone': '0905111222',
      'description': 'Sân thảm PVC chuẩn thi đấu tại Hải Châu.',
      'courts': [
        {
          'id': 301,
          'facilityId': 31,
          'name': 'Sân VIP 1',
          'courtType': 'INDOOR',
          'status': 'ACTIVE',
          'timeSlots': [
            {
              'id': 3001,
              'courtId': 301,
              'dayOfWeek': 1,
              'startTime': '06:00',
              'endTime': '07:00',
              'price': 80000,
              'isActive': true,
            },
            {
              'id': 3002,
              'courtId': 301,
              'dayOfWeek': 1,
              'startTime': '18:00',
              'endTime': '19:00',
              'price': 110000,
              'isActive': true,
            },
          ],
        },
        {
          'id': 302,
          'facilityId': 31,
          'name': 'Sân VIP 2',
          'courtType': 'INDOOR',
          'status': 'ACTIVE',
          'timeSlots': [
            {
              'id': 3003,
              'courtId': 302,
              'dayOfWeek': 1,
              'startTime': '06:00',
              'endTime': '07:00',
              'price': 90000,
              'isActive': true,
            },
          ],
        },
      ],
      'operatingHours': [
        {
          'id': 1,
          'facilityId': 31,
          'dayOfWeek': 1,
          'openTime': '06:00',
          'closeTime': '22:00',
        },
      ],
    },
    {
      'id': 32,
      'ownerId': 2,
      'name': 'Sân Cầu Lông Sơn Trà Arena',
      'address': '15 Ngô Quyền, Sơn Trà, Đà Nẵng',
      'latitude': 16.0850,
      'longitude': 108.2350,
      'courts': [
        {
          'id': 303,
          'facilityId': 32,
          'name': 'Sân A',
          'courtType': 'INDOOR',
          'status': 'ACTIVE',
          'timeSlots': [],
        },
      ],
      'operatingHours': [],
    },
  ];

  test('CourtLocation.fromJson maps supported NestJS /facilities fields without fabricating values', () {
    final first = CourtLocation.fromJson(sampleApiFacilitiesJson[0]);
    expect(first.id, 31);
    expect(first.name, 'CLB Cầu Lông Hải Châu Live');
    expect(first.address, '88 Nguyễn Văn Linh, Hải Châu, Đà Nẵng');
    expect(first.latitude, 16.0605);
    expect(first.longitude, 108.2155);
    expect(first.contactPhone, '0905111222');
    expect(first.description, 'Sân thảm PVC chuẩn thi đấu tại Hải Châu.');
    expect(first.courts, hasLength(2));
    expect(first.operatingHoursText, '06:00 - 22:00');
    expect(first.priceSummary, '80000 - 110000 VND / hour');
    expect(first.demo, isFalse);
    // Unsupported fields must remain null rather than fabricated:
    expect(first.rating, isNull);
    expect(first.reviewCount, isNull);
    expect(first.distanceKm, isNull);
    expect(first.isOpen, isNull);
    expect(first.priceRange, isNull);

    final second = CourtLocation.fromJson(sampleApiFacilitiesJson[1]);
    expect(second.id, 32);
    expect(second.operatingHoursText, isNull);
    expect(second.priceSummary, isNull);
    expect(second.rating, isNull);
    expect(second.distanceKm, isNull);
    expect(second.isOpen, isNull);
  });

  test('nearbyCourtsProvider fetches /facilities via Dio and filters out demo/non-positive IDs', () async {
    final client = ApiClient.instance;
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/facilities') {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: [
                ...sampleApiFacilitiesJson,
                {
                  'id': -1001,
                  'name': 'Negative Demo Facility',
                  'address': 'Fake',
                },
              ],
            ),
          );
          return;
        }
        handler.next(options);
      },
    );
    client.dio.interceptors.add(interceptor);
    addTearDown(() => client.dio.interceptors.remove(interceptor));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final facilities = await container.read(nearbyCourtsProvider.future);
    expect(facilities.map((f) => f.id).toList(), [31, 32]);
    expect(facilities.any((f) => f.id <= 0 || f.demo), isFalse);
  });

  testWidgets(
    'PlayerHomeScreen handles loading, error + retry, empty + refresh, and renders real facilities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final completer = Completer<List<CourtLocation>>();
      var attempt = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWith((ref) {
              attempt++;
              if (attempt == 1) return completer.future;
              if (attempt == 2) return Future.value(const <CourtLocation>[]);
              return Future.value(
                sampleApiFacilitiesJson.map(CourtLocation.fromJson).toList(),
              );
            }),
          ],
          child: const MaterialApp(home: PlayerHomeScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Fail first attempt -> Error state
      completer.completeError(Exception('Network error'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load courts. Please try again.'),
        findsOneWidget,
      );

      // Tap Retry -> Empty state
      await tester.tap(find.byKey(const Key('home_courts_retry')));
      await tester.pumpAndSettle();
      expect(
        find.text('No registered facilities available yet.'),
        findsOneWidget,
      );

      // Tap Refresh -> Real facilities loaded without DemoCatalog fallback
      await tester.tap(find.byKey(const Key('home_courts_empty_refresh')));
      await tester.pumpAndSettle();
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsOneWidget);
      expect(find.text('Sân Cầu Lông Sơn Trà Arena'), findsOneWidget);
      expect(find.text('10 demo facilities · Local catalogue'), findsNothing);
      expect(find.text('Hai Chau Badminton'), findsNothing);
    },
  );

  testWidgets(
    'ExploreCourtsScreen handles loading, error, empty, search filtering, and live data',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var attempt = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWith((ref) async {
              attempt++;
              if (attempt == 1) throw Exception('Server down');
              if (attempt == 2) return const <CourtLocation>[];
              return sampleApiFacilitiesJson
                  .map(CourtLocation.fromJson)
                  .toList();
            }),
          ],
          child: const MaterialApp(home: ExploreCourtsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load courts. Please try again.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('explore_courts_retry')));
      await tester.pumpAndSettle();
      expect(
        find.text('No registered facilities available yet.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('explore_courts_empty_refresh')));
      await tester.pumpAndSettle();
      expect(find.text('2 facilities'), findsOneWidget);
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsOneWidget);
      // Prices are now rendered in the Services table from actual slot data.
      expect(find.text('Sân Cầu Lông Sơn Trà Arena'), findsOneWidget);
      expect(find.text('Chưa có giá'), findsOneWidget);

      // Filter by area/name
      await tester.enterText(find.byType(TextField), 'Sơn Trà');
      await tester.pumpAndSettle();
      expect(find.text('1 facility'), findsOneWidget);
      expect(find.text('Sân Cầu Lông Sơn Trà Arena'), findsOneWidget);
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsNothing);

      // Filter with no match
      await tester.enterText(find.byType(TextField), 'NonExistentDistrict');
      await tester.pumpAndSettle();
      expect(
        find.text('No courts match your search. Try another area.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Home, Explore, Search, and Map display consistent facilities and navigate to CourtPreviewScreen -> LiveFacilitySchedule with real IDs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final facilities = sampleApiFacilitiesJson
          .map(CourtLocation.fromJson)
          .toList();
      final client = ApiClient.instance;
      final requestedPaths = <String>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedPaths.add(options.path);
          if (options.path == '/facilities/31') {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: sampleApiFacilitiesJson[0],
              ),
            );
            return;
          }
          if (options.path.contains('/time-slots/availability')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: [
                  {
                    'id': 3003,
                    'startTime': '20:00',
                    'endTime': '21:00',
                    'isActive': true,
                    'isBooked': false,
                    'price': 90000,
                  },
                ],
              ),
            );
            return;
          }
          handler.next(options);
        },
      );
      client.dio.interceptors.add(interceptor);
      addTearDown(() => client.dio.interceptors.remove(interceptor));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWith((ref) async => facilities),
          ],
          child: const MaterialApp(home: PlayerHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Home shows the real facility
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsOneWidget);
      await tester.tap(find.text('CLB Cầu Lông Hải Châu Live'));
      await tester.pumpAndSettle();

      // 2. Opens CourtPreviewScreen with the exact same CourtLocation (id: 31)
      final previewFromHome = tester.widget<CourtPreviewScreen>(
        find.byType(CourtPreviewScreen),
      );
      expect(previewFromHome.location?.id, 31);
      expect(find.textContaining('06:00 - 22:00'), findsOneWidget);
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      // Prices are now rendered in the Services table from actual slot data.
      expect(
        find.text('Sân thảm PVC chuẩn thi đấu tại Hải Châu.'),
        findsOneWidget,
      );

      // 3. Tapping a specific court card ('Sân VIP 2', id: 302) navigates to LiveFacilitySchedule with facilityId: 31, initialCourtId: 302
      await tester.ensureVisible(find.text('Sân VIP 2'));
      await tester.tap(find.text('Sân VIP 2'));
      await tester.pumpAndSettle();

      final schedule = tester.widget<LiveFacilitySchedule>(
        find.byType(LiveFacilitySchedule),
      );
      expect(schedule.facilityId, 31);
      expect(schedule.initialCourtId, 302);
      expect(schedule.demo, isFalse);
      expect(
        requestedPaths,
        contains('/facilities/31/courts/302/time-slots/availability'),
      );

      // Pop back to Home
      Navigator.of(tester.element(find.byType(LiveFacilitySchedule))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(CourtPreviewScreen))).pop();
      await tester.pumpAndSettle();

      // 4. Open Explore Map from Home and verify Map has the exact same facilities [31, 32]
      await tester.tap(find.text('Explore Map'));
      await tester.pumpAndSettle();
      expect(find.byType(FindCourtsMapScreen), findsOneWidget);
      final mapWidget = tester.widget<CourtMapLibreMap>(
        find.byType(CourtMapLibreMap),
      );
      expect(mapWidget.courts.map((c) => c.id).toList(), [31, 32]);
    },
  );

  testWidgets(
    'ExperienceSearchScreen and FindCourtsMapScreen handle error/empty states and open CourtPreviewScreen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final facilities = sampleApiFacilitiesJson
          .map(CourtLocation.fromJson)
          .toList();
      var searchAttempt = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWith((ref) async {
              searchAttempt++;
              if (searchAttempt == 1) throw Exception('Search API error');
              return facilities;
            }),
          ],
          child: const MaterialApp(home: ExperienceSearchScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unable to load courts.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('search_courts_retry')));
      await tester.pumpAndSettle();
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sơn Trà Arena');
      await tester.pumpAndSettle();
      expect(find.text('Sân Cầu Lông Sơn Trà Arena'), findsOneWidget);
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsNothing);

      await tester.tap(find.text('Sân Cầu Lông Sơn Trà Arena'));
      await tester.pumpAndSettle();
      final preview = tester.widget<CourtPreviewScreen>(
        find.byType(CourtPreviewScreen),
      );
      expect(preview.location?.id, 32);

      // Verify FindCourtsMapScreen empty registered facilities state and reload
      var mapAttempt = 0;
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            nearbyCourtsProvider.overrideWith((ref) async {
              mapAttempt++;
              if (mapAttempt == 1) return const <CourtLocation>[];
              return facilities;
            }),
          ],
          child: MaterialApp(
            key: UniqueKey(),
            home: const FindCourtsMapScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có cơ sở đăng ký. Tải lại'), findsOneWidget);

      await tester.tap(find.text('Chưa có cơ sở đăng ký. Tải lại'));
      await tester.pumpAndSettle();
      expect(find.text('CLB Cầu Lông Hải Châu Live'), findsWidgets);
    },
  );
}
