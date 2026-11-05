import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';
import 'package:mobile/features/booking/screens/booking_summary_screen.dart';
import 'package:mobile/features/booking/screens/booking_success_screen.dart';

class BookingFake extends LiveBookingService {
  final submitted = Completer<Map<String, dynamic>>();
  int calls = 0;
  @override
  Future<Map<String, dynamic>> facility(int id) async => {
    'id': id,
    'name': 'Selected Facility',
    'address': 'Selected Address',
    'courts': [
      {
        'id': 51,
        'name': 'Selected Court',
        'courtType': 'INDOOR',
        'status': 'ACTIVE',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async => [
    {'id': 80, 'startTime': '18:00', 'endTime': '19:00', 'isActive': true},
  ];
  @override
  Future<Map<String, dynamic>> book({
    required int courtId,
    required String startTime,
    required String endTime,
  }) {
    expect(courtId, 51);
    expect(startTime, '2026-11-09T18:00:00+07:00');
    expect(endTime, '2026-11-09T19:00:00+07:00');
    calls++;
    return submitted.future;
  }
}

void main() {
  test('Booking sends only the authenticated existing API contract', () async {
    final dio = Dio();
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          paths.add(o.path);
          if (o.method == 'POST') {
            expect(o.data, {
              'courtId': 51,
              'startTime': '2026-11-09T18:00:00+07:00',
              'endTime': '2026-11-09T19:00:00+07:00',
            });
            expect(o.extra['expectedAuthToken'], 'session');
            h.resolve(
              Response(
                requestOptions: o,
                data: {'id': 90, 'totalPrice': 100000},
              ),
            );
          } else {
            expect(o.queryParameters['date'], '2026-11-09');
            h.resolve(Response(requestOptions: o, data: []));
          }
        },
      ),
    );
    final service = LiveBookingService(dio: dio, token: () => 'session');
    await service.slots(45, 51, '2026-11-09');
    final booking = await service.book(
      courtId: 51,
      startTime: '2026-11-09T18:00:00+07:00',
      endTime: '2026-11-09T19:00:00+07:00',
    );
    expect(booking['id'], 90);
    expect(paths, [
      '/facilities/45/courts/51/time-slots/availability',
      '/bookings',
    ]);
  });
  test('Unauthenticated booking does not make a request', () async {
    final service = LiveBookingService(dio: Dio(), token: () => null);
    await expectLater(
      service.book(courtId: 51, startTime: 'start', endTime: 'end'),
      throwsStateError,
    );
  });
  for (final conflict in [false, true]) {
    testWidgets(
      'Live booking preserves selection, prevents double submit; conflict=$conflict',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fake = BookingFake();
        await tester.pumpWidget(
          MaterialApp(
            home: LiveFacilitySchedule(
              facilityId: 45,
              service: fake,
              now: () => DateTime.utc(2026, 11, 9, 1),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('18:00 – 19:00'));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(BookingSummaryScreen), findsOneWidget);
        expect(find.text('Selected Court'), findsOneWidget);
        await tester.tap(find.text('Confirm Booking'));
        await tester.pump();
        expect(fake.calls, 1);
        expect(find.text('Confirming…'), findsOneWidget);
        if (conflict) {
          fake.submitted.completeError(
            DioException(
              requestOptions: RequestOptions(path: '/bookings'),
              response: Response(
                requestOptions: RequestOptions(path: '/bookings'),
                statusCode: 409,
              ),
            ),
          );
        } else {
          fake.submitted.complete({'id': 90, 'totalPrice': 100000});
        }
        await tester.pumpAndSettle();
        expect(
          find.byType(BookingSuccessScreen),
          conflict ? findsNothing : findsOneWidget,
        );
        if (conflict) {
          expect(
            find.textContaining('Khung giờ vừa có người đặt'),
            findsOneWidget,
          );
        } else {
          expect(find.textContaining('100000 VND'), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
