import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';
import 'package:mobile/features/booking/screens/booking_summary_screen.dart';
import 'package:mobile/features/booking/screens/booking_success_screen.dart';

class BookingFake extends LiveBookingService {
  final submitted = Completer<Map<String, dynamic>>();
  int calls = 0;
  bool booked = false;
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
    {
      'id': 80,
      'startTime': '18:00',
      'endTime': '19:00',
      'isActive': true,
      'price': 125000,
      'isBooked': booked,
    },
  ];
  @override
  Future<Map<String, dynamic>> book({
    int? facilityId,
    required int courtId,
    required String startTime,
    required String endTime,
  }) {
    expect(facilityId, 45);
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
              'facilityId': 45,
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
      facilityId: 45,
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
  test('Live service rejects sandbox IDs before any request', () async {
    final service = LiveBookingService(dio: Dio(), token: () => 'session');
    await expectLater(service.facility(-1), throwsStateError);
    await expectLater(service.slots(45, -1, '2026-11-09'), throwsStateError);
    await expectLater(
      service.book(courtId: -1, startTime: 'start', endTime: 'end'),
      throwsStateError,
    );
  });

  testWidgets(
    'Empty schedule disables Continue and API failure supports retry',
    (tester) async {
      final dio = Dio();
      var fail = true;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (fail) {
              h.reject(
                DioException(
                  requestOptions: o,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              h.resolve(
                Response(
                  requestOptions: o,
                  data: {'id': 45, 'name': 'Empty facility', 'courts': []},
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveFacilitySchedule(
            facilityId: 45,
            service: LiveBookingService(dio: dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Không tải được lịch sân'), findsOneWidget);
      fail = false;
      await tester.tap(find.textContaining('Không tải được lịch sân'));
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở chưa có sân đang hoạt động.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Requested court is preserved and booked slots cannot be selected',
    (tester) async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == '/facilities/45') {
              h.resolve(
                Response(
                  requestOptions: o,
                  data: {
                    'id': 45,
                    'name': 'Selected facility',
                    'courts': [
                      {'id': 50, 'name': 'First court', 'status': 'ACTIVE'},
                      {'id': 51, 'name': 'Requested court', 'status': 'ACTIVE'},
                    ],
                  },
                ),
              );
            } else {
              expect(
                o.path,
                '/facilities/45/courts/51/time-slots/availability',
              );
              h.resolve(
                Response(
                  requestOptions: o,
                  data: [
                    {
                      'id': 1,
                      'startTime': '18:00',
                      'endTime': '19:00',
                      'price': 125000,
                      'isBooked': true,
                    },
                  ],
                ),
              );
            }
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LiveFacilitySchedule(
            facilityId: 45,
            initialCourtId: 51,
            service: LiveBookingService(dio: dio),
            now: () => DateTime.utc(2026, 11, 9, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Requested court'),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Đã đặt'), findsOneWidget);
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Submit network error stays on summary and directs the player to check history',
    (tester) async {
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
      await tester.tap(find.text('Confirm Booking'));
      await tester.pump();
      fake.submitted.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/bookings'),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingSuccessScreen), findsNothing);
      expect(find.textContaining('kiểm tra lịch sử đặt sân'), findsOneWidget);
      expect(fake.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
        expect(find.text('125000 VND'), findsWidgets);
        await tester.tap(find.text('Confirm Booking'));
        await tester.pump();
        expect(fake.calls, 1);
        expect(find.text('Confirming…'), findsOneWidget);
        if (conflict) {
          fake.booked = true;
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
          expect(
            tester
                .widget<ElevatedButton>(
                  find.widgetWithText(ElevatedButton, 'Confirm Booking'),
                )
                .onPressed,
            isNull,
          );
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.text('Đã đặt'), findsOneWidget);
          expect(fake.calls, 1);
        } else {
          expect(find.textContaining('100000 VND'), findsWidgets);
          final client = ApiClient.instance;
          final old = client.token;
          client.setToken('history-session');
          final history = InterceptorsWrapper(
            onRequest: (o, h) {
              expect(o.path, '/bookings/my');
              h.resolve(
                Response(
                  requestOptions: o,
                  data: [
                    {
                      'id': 90,
                      'status': 'CONFIRMED',
                      'totalPrice': 100000,
                      'startTime': '2026-11-09T11:00:00Z',
                      'endTime': '2026-11-09T12:00:00Z',
                      'court': {
                        'name': 'Selected Court',
                        'facility': {'name': 'Selected Facility'},
                      },
                    },
                  ],
                ),
              );
            },
          );
          client.dio.interceptors.add(history);
          addTearDown(() {
            client.dio.interceptors.remove(history);
            client.setToken(old);
          });
          await tester.tap(find.text('View My Bookings'));
          await tester.pumpAndSettle();
          expect(find.byType(BookingHistoryScreen), findsOneWidget);
          expect(find.text('Selected Facility'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
