import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/widgets/facility_services.dart';

void main() {
  test(
    'half-hour tariff boundary retains hourly display and exact slot charges',
    () {
      final slots = [
        {
          'dayOfWeek': 1,
          'startTime': '10:30',
          'endTime': '11:30',
          'price': 70000,
          'hourlyRate': 70000,
          'walkInPrice': 80000,
        },
        {
          'dayOfWeek': 1,
          'startTime': '11:30',
          'endTime': '12:00',
          'price': 35000,
          'hourlyRate': 70000,
          'walkInPrice': 40000,
        },
      ];
      final rows = facilityTariffs([
        {'name': 'Court 1', 'timeSlots': slots},
      ]).single.rows;
      expect(rows, hasLength(1));
      expect(rows.single['startTime'], '10:30');
      expect(rows.single['endTime'], '12:00');
      expect(rows.single['price'], 70000);
      expect(rows.single['walkInPrice'], 80000);
      expect(slots.last['price'], 35000);
    },
  );
  final courts = [
    for (var i = 1; i <= 6; i++)
      {
        'name': 'Court $i',
        'status': 'ACTIVE',
        'timeSlots': [
          for (var day = 0; day < 7; day++)
            {
              'dayOfWeek': day,
              'startTime': '06:00',
              'endTime': '07:00',
              'price': 80000,
            },
        ],
      },
  ];
  test('groups identical tariffs without manufacturing walk-in prices', () {
    final groups = facilityTariffs(courts);
    expect(groups.length, 1);
    expect(groups.single.days, 'Mon–Sun');
    expect(groups.single.courts, contains('Court 6'));
    expect(groups.single.rows.single['price'], 80000);
    expect(facilityTariffs([]), isEmpty);
  });
  test('Different supplied walk-in tariffs remain separate; missing values stay null', () {
    final groups = facilityTariffs([
      {
        'name': 'Court 1',
        'status': 'ACTIVE',
        'timeSlots': [
          {
            'dayOfWeek': 1,
            'startTime': '06:00',
            'endTime': '07:00',
            'price': 80000,
            'walkInPrice': 90000,
          },
          {
            'dayOfWeek': 1,
            'startTime': '07:00',
            'endTime': '08:00',
            'price': 80000,
            'walkInPrice': 95000,
          },
          {
            'dayOfWeek': 1,
            'startTime': '08:00',
            'endTime': '09:00',
            'price': 80000,
          },
        ],
      },
    ]);
    expect(groups.single.rows, hasLength(3));
    expect(groups.single.rows.last['walkInPrice'], isNull);
  });
  testWidgets(
    'Services render only the names, prices and units supplied by the caller',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FacilityServices(
                courts: courts,
                services: const [
                  FacilityServiceItem(
                    name: 'Published service',
                    price: 12000,
                    unit: 'unit',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published service'), findsOneWidget);
      expect(find.text('12,000 ₫ / unit'), findsOneWidget);
      expect(find.text('No services listed yet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [393.0, 320.0]) {
    testWidgets('Services fits $width without overflow', (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FacilityServices(courts: courts),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Court pricing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
