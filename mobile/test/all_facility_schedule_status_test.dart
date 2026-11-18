import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/booking/booking_theme.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';

class ScheduleFixture extends LiveBookingService {
  ScheduleFixture(this.facilityId, this.name, this.courtCount);

  final int facilityId;
  final String name;
  final int courtCount;

  @override
  Future<Map<String, dynamic>> facility(int id) async {
    expect(id, facilityId);
    return {
      'id': id,
      'name': name,
      'operatingHours': [
        for (var day = 0; day < 7; day++)
          {'dayOfWeek': day, 'openTime': '05:00', 'closeTime': '23:00'},
      ],
      'courts': [
        for (var court = 1; court <= courtCount; court++)
          {'id': id * 100 + court, 'name': 'Court $court', 'status': 'ACTIVE'},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async {
    expect(facilityId, this.facilityId);
    expect(courtId ~/ 100, facilityId);
    return [
      for (final data in [
        (5, 'AVAILABLE', false, true, 80000),
        (6, 'BOOKED', true, true, 80000),
        (7, 'LOCKED', false, false, 80000),
        (12, 'AVAILABLE', false, true, 90000),
        (13, 'BOOKED', true, true, 90000),
        (14, 'EVENT', false, true, 90000),
        (15, 'AVAILABLE', false, true, null),
        (23, 'LOCKED', false, false, null),
      ])
        {
          'id': courtId * 100 + data.$1,
          'startTime': '${data.$1.toString().padLeft(2, '0')}:00',
          'endTime': '${(data.$1 + 1).toString().padLeft(2, '0')}:00',
          'status': data.$2,
          'isBooked': data.$3,
          'isActive': data.$4,
          'price': data.$5,
        },
    ];
  }
}

void main() {
  const facilities = [
    (4, 'Hai Chau Badminton', 4),
    (5, 'Hoa Cuong Badminton', 6),
    (6, 'Thanh Khe Badminton', 4),
    (7, 'An Khe Badminton', 3),
    (8, 'An Hai Badminton', 4),
    (9, 'Son Tra Badminton', 6),
    (10, 'Ngu Hanh Son Badminton', 4),
    (11, 'Hoa Xuan Badminton', 5),
    (12, 'Cam Le Badminton', 4),
    (13, 'Hoa Khanh Badminton', 6),
  ];

  for (final facility in facilities) {
    testWidgets(
      '${facility.$2}: every court uses API status, not time, for color',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: LiveFacilitySchedule(
              facilityId: facility.$1,
              service: ScheduleFixture(facility.$1, facility.$2, facility.$3),
              // 11:00 in Vietnam: 05:00 is past and 12:00 is future.
              now: () => DateTime.utc(2026, 11, 9, 4),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (var court = 1; court <= facility.$3; court++) {
          final id = facility.$1 * 100 + court;
          Finder cell(int start) => find.byKey(
            ValueKey(
              'slot-$id-${start.toString().padLeft(2, '0')}:00 – ${(start + 1).toString().padLeft(2, '0')}:00',
            ),
          );
          Color color(int start) =>
              (tester
                          .widget<Container>(
                            find
                                .descendant(
                                  of: cell(start),
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .color!;
          bool canTap(int start) =>
              tester.widget<InkWell>(cell(start)).onTap != null;

          expect(color(5), Colors.white);
          expect(canTap(5), isFalse);
          expect(
            find.descendant(of: cell(5), matching: find.byType(Text)),
            findsNothing,
          );
          expect(color(6), BookingColors.slotBooked);
          expect(canTap(6), isFalse);
          expect(color(7), BookingColors.slotLocked);
          expect(canTap(7), isFalse);
          expect(color(12), Colors.white);
          expect(canTap(12), isTrue);
          expect(color(13), BookingColors.slotBooked);
          expect(canTap(13), isFalse);
          expect(color(14), BookingColors.slotEvent);
          expect(canTap(14), isFalse);
          expect(color(15), Colors.white);
          expect(canTap(15), isFalse);
          expect(color(23), BookingColors.slotLocked);
          expect(canTap(23), isFalse);
        }
        expect(find.text('Past'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
