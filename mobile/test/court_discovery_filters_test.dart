import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/exploration_data.dart';

void main() {
  CourtLocation facility({
    List<Map<String, dynamic>> hours = const [],
    List<Map<String, dynamic>> courts = const [],
  }) => CourtLocation(
    id: 1,
    name: 'Test',
    latitude: 16,
    longitude: 108,
    operatingHours: hours,
    courts: courts,
  );
  test('opening hours use Vietnam time and exclusive closing boundary', () {
    final court = facility(
      hours: [
        {'dayOfWeek': 0, 'openTime': '05:00', 'closeTime': '23:00'},
      ],
    );
    expect(court.isOpenAt(DateTime.utc(2026, 11, 22, 0)), true);
    expect(court.isOpenAt(DateTime.utc(2026, 11, 22, 16)), false);
    expect(court.isOpenAt(DateTime.utc(2026, 11, 23, 0)), isNull);
  });
  test('overnight hours carry into following day', () {
    final court = facility(
      hours: [
        {'dayOfWeek': 6, 'openTime': '22:00', 'closeTime': '02:00'},
      ],
    );
    expect(court.isOpenAt(DateTime.utc(2026, 11, 21, 18)), true);
    expect(facility().currentlyOpen, isNull);
  });
  test(
    'price filters use hourly API values and ignore inactive courts/slots',
    () {
      final court = facility(
        courts: [
          {
            'status': 'INACTIVE',
            'timeSlots': [
              {'hourlyRate': 1},
            ],
          },
          {
            'status': 'ACTIVE',
            'timeSlots': [
              {'isActive': false, 'hourlyRate': 2},
              {'price': 60000, 'startTime': '12:00', 'endTime': '12:30'},
            ],
          },
        ],
      );
      expect(court.startingHourlyRate, 120000);
      expect(court.priceSummary, '120000 VND / hour');
      expect(court.discoveryPriceBand, r'$$');
      expect(facility().discoveryPriceBand, isNull);
    },
  );
}
