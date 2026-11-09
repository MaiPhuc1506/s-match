import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/screens/court_preview_screen.dart';
import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';

import 'support/fake_court_map_platform.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'Map → selected facility → non-first court → booking → live Player history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final platform = MapLibrePlatform.createInstance;
      MapLibrePlatform.createInstance = FakeCourtMapPlatform.new;
      addTearDown(() => MapLibrePlatform.createInstance = platform);
      final client = ApiClient.instance;
      final oldToken = client.token;
      client.setToken('booking-map-test');
      final tomorrow = DateUtils.dateOnly(
        DateTime.now().toUtc().add(const Duration(hours: 7, days: 1)),
      );
      String ymd(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final courts = [
        {
          'id': 51,
          'name': 'First court',
          'status': 'ACTIVE',
          'courtType': 'INDOOR',
        },
        {
          'id': 52,
          'name': 'Selected court',
          'status': 'ACTIVE',
          'courtType': 'INDOOR',
        },
      ];
      final facility = {
        'id': 45,
        'name': 'Map-selected facility',
        'address': 'Actual API address',
        'courts': courts,
      };
      Map<String, dynamic>? persisted;
      final writes = <Map>[];
      final interceptor = InterceptorsWrapper(
        onRequest: (o, h) {
          Object? body;
          if (o.path == '/facilities/45') {
            body = facility;
          } else if (o.path.contains('/time-slots/availability')) {
            expect(
              o.path,
              matches(
                RegExp(
                  r'^/facilities/45/courts/(51|52)/time-slots/availability$',
                ),
              ),
            );
            body = [
              {
                'id': 80,
                'startTime': '18:00',
                'endTime': '19:00',
                'isActive': true,
                'isBooked': false,
                'price': 125000,
              },
            ];
          } else if (o.path == '/bookings') {
            final data = Map<String, dynamic>.from(o.data as Map);
            expect(data, {
              'facilityId': 45,
              'courtId': 52,
              'startTime': '${ymd(tomorrow)}T18:00:00+07:00',
              'endTime': '${ymd(tomorrow)}T19:00:00+07:00',
            });
            writes.add(data);
            persisted = {
              ...data,
              'id': 90,
              'status': 'CONFIRMED',
              'totalPrice': 125000,
              'court': {...courts[1], 'facility': facility},
            };
            body = persisted;
          } else if (o.path == '/bookings/my') {
            body = [persisted!];
          } else {
            fail('Unexpected request: ${o.path}');
          }
          h.resolve(
            Response(
              requestOptions: o,
              statusCode: o.method == 'POST' ? 201 : 200,
              data: body,
            ),
          );
        },
      );
      client.dio.interceptors.add(interceptor);
      addTearDown(() {
        client.dio.interceptors.remove(interceptor);
        client.setToken(oldToken);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nearbyCourtsProvider.overrideWith(
              (ref) async => [
                CourtLocation.fromJson({
                  ...facility,
                  'latitude': 16.06,
                  'longitude': 108.21,
                }),
              ],
            ),
          ],
          child: const MaterialApp(home: FindCourtsMapScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('find_courts_sheet_summary')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Map-selected facility').last);
      await tester.pumpAndSettle();
      expect(find.byType(CourtPreviewScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('view_courts')));
      await tester.pumpAndSettle();
      expect(find.byType(LiveFacilitySchedule), findsOneWidget);
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(tomorrow);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected court'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18:00 – 19:00'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Selected court'), findsOneWidget);
      expect(find.text('125000 VND'), findsWidgets);
      await tester.tap(find.text('Confirm Booking'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      await tester.tap(find.text('View My Bookings'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingHistoryScreen), findsOneWidget);
      expect(find.text('Map-selected facility'), findsOneWidget);
      expect(find.text('Selected court'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Demo location never enters the live schedule', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CourtPreviewScreen(
            location: CourtLocation(
              id: 45,
              name: 'Demo facility',
              latitude: 16,
              longitude: 108,
              demo: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('view_courts')));
    await tester.pump();
    expect(find.byType(LiveFacilitySchedule), findsNothing);
    expect(find.textContaining('Sân minh họa không thể đặt'), findsOneWidget);
  });
}
