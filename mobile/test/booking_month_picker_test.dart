import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/widgets/booking_month_picker.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';

class CalendarScheduleService extends LiveBookingService {
  final dates = <String>[];
  @override
  Future<Map<String, dynamic>> facility(int id) async => {
    'id': id,
    'name': 'API facility',
    'courts': [
      for (var i = 1; i <= 6; i++)
        {
          'id': i,
          'name': 'Court $i',
          'status': 'ACTIVE',
          'courtType': 'INDOOR',
        },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async {
    dates.add(date);
    return [
      {
        'id': courtId,
        'startTime': '20:30',
        'endTime': '21:00',
        'isActive': true,
        'isBooked': false,
        'status': 'AVAILABLE',
        'price': 45000,
      },
    ];
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
    'full-screen schedule opens only one centered month dialog and preserves date flow',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CalendarScheduleService();
      final page = Scaffold(
        body: SafeArea(
          child: LiveFacilitySchedule(
            facilityId: 45,
            compact: true,
            service: service,
            now: () => DateTime.utc(2026, 11, 23, 1),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => page)),
                    child: const Text('Open schedule'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open schedule'));
      await tester.pumpAndSettle();
      expect(service.dates, everyElement('2026-11-23'));
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('booking-schedule-content'))),
        const Size(393, 852),
      );
      expect(find.text('Booking Schedule'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.byKey(const Key('booking-month-trigger')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('booking-schedule-content')), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.byType(DatePickerDialog), findsNothing);
      final calendar = find.descendant(
        of: find.byKey(const Key('booking-month-dialog')),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.getCenter(calendar).dx, closeTo(196.5, 1));
      expect(tester.getCenter(calendar).dy, closeTo(426, 1));
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('booking-day-2026-11-22')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const ValueKey('booking-month-arrow--1')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('booking-day-2026-11-24')));
      await tester.pumpAndSettle();
      expect(service.dates.length, 6);
      await tester.tap(find.byKey(const Key('booking-month-cancel')));
      await tester.pumpAndSettle();
      expect(service.dates.length, 6);
      await tester.tap(find.byKey(const Key('booking-month-trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('booking-day-2026-11-24')));
      await tester.tap(find.byKey(const Key('booking-month-confirm')));
      await tester.pumpAndSettle();
      expect(service.dates.skip(6), everyElement('2026-11-24'));
      expect(service.dates.length, 12);
      await tester.tap(find.byKey(const ValueKey('slot-1-20:30 – 21:00')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking-continue')));
      await tester.pumpAndSettle();
      expect(find.text('Normal Booking'), findsOneWidget);
      expect(find.text('Organize Open Match'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('month navigation respects the last bookable month', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookingMonthPicker(
          selectedDate: DateTime(2026, 11, 23),
          firstDate: DateTime(2026, 11, 23),
          lastDate: DateTime(2026, 12, 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-month-arrow-1')));
    await tester.pumpAndSettle();
    expect(find.text('December 2026'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('booking-month-arrow-1')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('booking-day-2026-12-2')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<CupertinoButton>(
            find.byKey(const ValueKey('booking-day-2026-12-3')),
          )
          .onPressed,
      isNull,
    );
  });
}
