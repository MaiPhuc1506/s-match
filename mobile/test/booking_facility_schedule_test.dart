import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/booking/screens/booking_facility_schedule_screen.dart';

void main() {
  testWidgets('schedule remains selectable after viewing Facility Info', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BookingFacilityScheduleScreen(
          onContinue: () => continued = true,
        ),
      ),
    );

    expect(find.text('6 Courts'), findsOneWidget);
    expect(find.text('Sân 3'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);

    await tester.tap(find.text('Facility Info'));
    await tester.pump();
    expect(find.text('Address: 123 Le Van Viet, D9, HCMC'), findsOneWidget);
    expect(find.text('Opening hours: 06:00 – 22:00'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);

    await tester.tap(find.text('Court Schedule'));
    await tester.pump();
    expect(find.text('Sân 3'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    expect(continued, isTrue);
  });
}
