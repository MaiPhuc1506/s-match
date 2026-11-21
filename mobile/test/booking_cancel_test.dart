import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/booking/screens/booking_detail_screen.dart';

void main() {
  testWidgets(
    'Live detail confirms cancellation and updates only after success',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetailScreen(
            readOnly: true,
            bookingId: '141',
            statusText: 'CONFIRMED',
            onCancelBooking: () async {
              calls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel Booking'));
      await tester.tap(find.text('Cancel Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Booking'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Cancel Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('Cancel Booking'), findsNothing);
    },
  );
  testWidgets('Failed cancellation retains booking status and permits retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BookingDetailScreen(
          readOnly: true,
          statusText: 'CONFIRMED',
          onCancelBooking: () async => throw StateError('network'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel Booking'));
    await tester.tap(find.text('Cancel Booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRMED'), findsOneWidget);
    expect(find.text('Cancel Booking'), findsOneWidget);
    expect(find.textContaining('Could not cancel'), findsOneWidget);
  });
}
