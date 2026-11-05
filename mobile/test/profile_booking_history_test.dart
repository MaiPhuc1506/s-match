import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/booking/screens/booking_detail_screen.dart';

void main() {
  testWidgets('Live booking details and back navigation', (tester) async {
    final client = ApiClient.instance;
    final oldToken = client.token;
    client.setToken('test');
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        expect(options.path, '/bookings/my');
        handler.resolve(
          Response(
            requestOptions: options,
            data: [
              {
                'id': 81,
                'status': 'CONFIRMED',
                'totalPrice': 125000,
                'startTime': '2026-11-05T10:00:00Z',
                'endTime': '2026-11-05T11:00:00Z',
                'court': {
                  'name': 'API Court',
                  'courtType': 'OUTDOOR',
                  'facility': {
                    'name': 'API Facility',
                    'address': 'API Address',
                  },
                },
              },
            ],
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
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const BookingHistoryScreen(live: true),
                ),
              ),
              child: const Text('Open bookings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open bookings'));
    await tester.pumpAndSettle();
    expect(find.text('API Facility'), findsOneWidget);
    expect(find.text('Sunrise Badminton Club'), findsNothing);
    await tester.tap(find.text('API Facility'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingDetailScreen), findsOneWidget);
    expect(find.text('OUTDOOR'), findsOneWidget);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.byType(BookingHistoryScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open bookings'), findsOneWidget);
  });
}
