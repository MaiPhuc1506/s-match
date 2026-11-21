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
import 'package:mobile/features/booking/booking_theme.dart';

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

class SelectionFake extends LiveBookingService {
  @override
  Future<Map<String, dynamic>> facility(int id) async => {
    'id': id,
    'name': 'Facility',
    'courts': [
      {'id': 51, 'name': 'Court 1', 'status': 'ACTIVE'},
      {'id': 52, 'name': 'Court 2', 'status': 'ACTIVE'},
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
      'price': courtId == 51 ? 125000 : 95000,
      'isBooked': false,
      'status': 'AVAILABLE',
    },
    {
      'id': 81,
      'startTime': '19:00',
      'endTime': '20:00',
      'isActive': true,
      'price': 110000,
      'isBooked': false,
      'status': 'AVAILABLE',
    },
  ];
}

class HalfHourFake extends SelectionFake {
  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async => [
    for (var i = 0; i < 4; i++)
      {
        'id': i ~/ 2,
        'startTime': '${18 + i ~/ 2}:${i.isEven ? '00' : '30'}',
        'endTime': '${18 + (i + 1) ~/ 2}:${i.isEven ? '30' : '00'}',
        'price': i < 2 ? 30000 : 45000,
        'isActive': true,
        'isBooked': false,
        'status': 'AVAILABLE',
      },
  ];
}

void main() {
  testWidgets('Half-hour cells extend into one priced range and summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveFacilitySchedule(
          facilityId: 45,
          service: HalfHourFake(),
          now: () => DateTime.utc(2026, 11, 9, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slot-51-18:30 – 19:00')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('slot-51-19:30 – 20:00')));
    await tester.pump();
    expect(find.text('Court 1 · 18:30–20:00'), findsOneWidget);
    expect(find.text('120,000 VND'), findsOneWidget);
    await tester.tap(find.byKey(const Key('booking-continue')));
    await tester.pumpAndSettle();
    expect(find.text('90 minutes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      expect(
        find.textContaining('Could not load court availability'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(
        find.textContaining('Could not load court availability'),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active courts at this facility.'), findsOneWidget);
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
                matches(
                  RegExp(
                    r'^/facilities/45/courts/(50|51)/time-slots/availability$',
                  ),
                ),
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
      expect(find.text('Requested court'), findsOneWidget);
      final bookedCell = find.byKey(const ValueKey('slot-51-18:00 – 19:00'));
      expect(tester.widget<InkWell>(bookedCell).onTap, isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('Schedule displays booked, available and closed cells from API', (
    tester,
  ) async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          h.resolve(
            Response(
              requestOptions: o,
              data: o.path == '/facilities/45'
                  ? {
                      'id': 45,
                      'name': 'Facility',
                      'operatingHours': [
                        {
                          'dayOfWeek': 1,
                          'openTime': '06:00',
                          'closeTime': '23:00',
                        },
                      ],
                      'courts': [
                        {'id': 51, 'name': 'Court 1', 'status': 'ACTIVE'},
                      ],
                    }
                  : [
                      {
                        'id': 3,
                        'startTime': '05:00',
                        'endTime': '06:00',
                        'price': 80000,
                        'isActive': true,
                        'isBooked': false,
                        'status': 'AVAILABLE',
                      },
                      {
                        'id': 1,
                        'startTime': '18:00',
                        'endTime': '19:00',
                        'price': 80000,
                        'isBooked': true,
                        'status': 'BOOKED',
                      },
                      {
                        'id': 2,
                        'startTime': '19:00',
                        'endTime': '20:00',
                        'price': 80000,
                        'isBooked': false,
                        'status': 'AVAILABLE',
                      },
                      {
                        'id': 4,
                        'startTime': '20:00',
                        'endTime': '21:00',
                        'price': 80000,
                        'isActive': false,
                        'isBooked': false,
                        'status': 'LOCKED',
                      },
                      {
                        'id': 5,
                        'startTime': '21:00',
                        'endTime': '22:00',
                        'isActive': true,
                        'isBooked': false,
                        'status': 'EVENT',
                      },
                      {
                        'id': null,
                        'startTime': '23:00',
                        'endTime': '24:00',
                        'isActive': false,
                        'isBooked': false,
                        'status': 'LOCKED',
                      },
                    ],
            ),
          );
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LiveFacilitySchedule(
          facilityId: 45,
          service: LiveBookingService(dio: dio),
          now: () => DateTime.utc(2026, 11, 9, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final booked = find.byKey(const ValueKey('slot-51-18:00 – 19:00'));
    final available = find.byKey(const ValueKey('slot-51-19:00 – 20:00'));
    final past = find.byKey(const ValueKey('slot-51-05:00 – 06:00'));
    final actualLock = find.byKey(const ValueKey('slot-51-20:00 – 21:00'));
    final locked = find.byKey(const ValueKey('slot-51-23:00 – 24:00'));
    final event = find.byKey(const ValueKey('slot-51-21:00 – 22:00'));
    Color cellColor(Finder finder) =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: finder,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(cellColor(booked), BookingColors.slotBooked);
    expect(cellColor(available), Colors.white);
    expect(cellColor(past), Colors.white);
    expect(cellColor(actualLock), BookingColors.slotLocked);
    expect(cellColor(locked), BookingColors.slotLocked);
    expect(cellColor(event), BookingColors.slotEvent);
    expect(find.text('Past'), findsNothing);
    expect(find.text('Selected'), findsOneWidget);
    expect(tester.widget<InkWell>(booked).onTap, isNull);
    expect(tester.widget<InkWell>(available).onTap, isNotNull);
    expect(tester.widget<InkWell>(past).onTap, isNull);
    expect(tester.widget<InkWell>(actualLock).onTap, isNull);
    expect(tester.widget<InkWell>(locked).onTap, isNull);
    expect(tester.widget<InkWell>(event).onTap, isNull);
  });

  testWidgets('Selection toggles, switches courts and uses the API price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveFacilitySchedule(
          facilityId: 45,
          service: SelectionFake(),
          now: () => DateTime.utc(2026, 11, 9, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('slot-51-18:00 – 19:00'));
    final second = find.byKey(const ValueKey('slot-52-18:00 – 19:00'));
    final later = find.byKey(const ValueKey('slot-52-19:00 – 20:00'));
    final continueButton = find.byKey(const Key('booking-continue'));
    Color cellColor(Finder slot) =>
        (tester
                    .widget<Container>(
                      find
                          .descendant(
                            of: slot,
                            matching: find.byType(Container),
                          )
                          .first,
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(cellColor(first), Colors.white);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(first);
    await tester.pump();
    expect(cellColor(first), BookingColors.primary);
    expect(find.text('Court 1 · 18:00–19:00'), findsOneWidget);
    expect(find.text('125,000 VND'), findsOneWidget);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

    await tester.tap(second);
    await tester.pump();
    expect(cellColor(first), Colors.white);
    expect(cellColor(second), BookingColors.primary);
    expect(find.text('Court 2 · 18:00–19:00'), findsOneWidget);
    expect(find.text('95,000 VND'), findsOneWidget);
    expect(find.text('125,000 VND'), findsNothing);

    await tester.tap(later);
    await tester.pump();
    expect(cellColor(second), BookingColors.primary);
    expect(cellColor(later), BookingColors.primary);
    expect(find.text('Court 2 · 18:00–20:00'), findsOneWidget);
    expect(find.text('205,000 VND'), findsOneWidget);

    await tester.tap(later);
    await tester.pump();
    expect(cellColor(later), Colors.white);
    expect(
      find.text('Choose consecutive time slots on one court.'),
      findsOneWidget,
    );
    expect(find.text('110,000 VND'), findsNothing);
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
  });

  testWidgets('Selection expires when the slot starts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveFacilitySchedule(
          facilityId: 45,
          service: SelectionFake(),
          now: () => DateTime.utc(2026, 11, 9, 10, 59, 58),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slot-51-18:00 – 19:00')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('booking-continue')))
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('booking-continue')))
          .onPressed,
      isNull,
    );
  });

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
      await tester.tap(find.byKey(const ValueKey('slot-51-18:00 – 19:00')));
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
        await tester.tap(find.byKey(const ValueKey('slot-51-18:00 – 19:00')));
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(BookingSummaryScreen), findsOneWidget);
        expect(find.text('Selected Court'), findsOneWidget);
        expect(find.text('125,000 VND'), findsWidgets);
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
            find.textContaining('This slot was just booked'),
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
          expect(
            tester
                .widget<InkWell>(
                  find.byKey(const ValueKey('slot-51-18:00 – 19:00')),
                )
                .onTap,
            isNull,
          );
          expect(fake.calls, 1);
        } else {
          expect(find.textContaining('100,000 VND'), findsWidgets);
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
  testWidgets('Small grid rechecks a slot before confirmation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fake = BookingFake();
    await tester.pumpWidget(
      MaterialApp(
        home: LiveFacilitySchedule(
          facilityId: 45,
          initialCourtId: 51,
          service: fake,
          now: () => DateTime.utc(2026, 11, 9, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('slot-51-18:00 – 19:00')));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSummaryScreen), findsOneWidget);
    fake.booked = true;
    await tester.tap(find.text('Confirm Booking'));
    await tester.pumpAndSettle();
    expect(fake.calls, 0);
    expect(
      find.textContaining('Availability or price changed'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
