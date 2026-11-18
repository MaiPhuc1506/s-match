import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/booking/booking_theme.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/facility/widgets/owner_facility_schedule.dart';

class OwnerScheduleFake extends LiveBookingService {
  final calls = <String>[];
  bool fail = false;
  final pending = <String, Completer<List<Map<String, dynamic>>>>{};
  bool delay = false;

  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) {
    calls.add('$facilityId/$courtId/$date');
    if (fail) return Future.error(StateError('offline'));
    if (delay) return pending.putIfAbsent(date, Completer.new).future;
    return Future.value([
      {
        'id': 1,
        'startTime': '05:00',
        'endTime': '06:00',
        'isActive': true,
        'isBooked': false,
        'status': 'AVAILABLE',
      },
      {
        'id': 2,
        'startTime': '06:00',
        'endTime': '07:00',
        'isActive': true,
        'isBooked': true,
        'status': 'BOOKED',
      },
      {
        'id': 3,
        'startTime': '07:00',
        'endTime': '08:00',
        'isActive': false,
        'isBooked': false,
        'status': 'LOCKED',
      },
    ]);
  }
}

void main() {
  const courts = [
    {'id': 51, 'name': 'Court 1', 'status': 'ACTIVE'},
    {'id': 52, 'name': 'Court 2', 'status': 'MAINTENANCE'},
  ];

  testWidgets('Owner sees real availability read-only, including maintenance', (
    tester,
  ) async {
    final service = OwnerScheduleFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerFacilitySchedule(
            facilityId: 45,
            courts: courts,
            date: DateTime(2026, 11, 9),
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.calls, ['45/51/2026-11-09']);
    Color color(int court, String time) =>
        (tester
                    .widget<Container>(
                      find.byKey(ValueKey('owner-slot-$court-$time')),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    expect(color(51, '05:00 – 06:00'), Colors.white);
    expect(color(51, '06:00 – 07:00'), BookingColors.slotBooked);
    expect(color(51, '07:00 – 08:00'), BookingColors.slotLocked);
    expect(color(52, '05:00 – 06:00'), BookingColors.slotLocked);
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.textContaining('UTC+7'), findsOneWidget);
  });

  testWidgets('API errors do not show invented availability and retry works', (
    tester,
  ) async {
    final service = OwnerScheduleFake()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerFacilitySchedule(
            facilityId: 45,
            courts: courts,
            date: DateTime(2026, 11, 9),
            service: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Không tải được lịch'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('owner-slot-51-05:00 – 06:00')),
      findsNothing,
    );
    service.fail = false;
    await tester.tap(find.textContaining('Không tải được lịch'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('owner-slot-51-05:00 – 06:00')),
      findsOneWidget,
    );
  });

  testWidgets('Changing date ignores stale responses', (tester) async {
    final service = OwnerScheduleFake()..delay = true;
    Widget screen(DateTime date) => MaterialApp(
      home: Scaffold(
        body: OwnerFacilitySchedule(
          facilityId: 45,
          courts: courts,
          date: date,
          service: service,
        ),
      ),
    );
    await tester.pumpWidget(screen(DateTime(2026, 11, 9)));
    await tester.pump();
    await tester.pumpWidget(screen(DateTime(2026, 11, 10)));
    await tester.pump();
    service.pending['2026-11-10']!.complete([
      {
        'id': 1,
        'startTime': '12:00',
        'endTime': '13:00',
        'isActive': true,
        'isBooked': false,
        'status': 'AVAILABLE',
      },
    ]);
    await tester.pumpAndSettle();
    service.pending['2026-11-09']!.complete([
      {
        'id': 2,
        'startTime': '06:00',
        'endTime': '07:00',
        'isActive': true,
        'isBooked': true,
        'status': 'BOOKED',
      },
    ]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('owner-slot-51-12:00 – 13:00')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('owner-slot-51-06:00 – 07:00')),
      findsNothing,
    );
  });
}
