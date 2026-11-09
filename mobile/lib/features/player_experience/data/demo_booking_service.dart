import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/services/live_booking_service.dart';
import '../../booking/screens/booking_history_screen.dart';
import 'demo_catalog.dart';

/// Session-only sandbox. Overrides every network operation; no production writes.
class DemoBookingService extends LiveBookingService {
  DemoBookingService(this.catalog, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  @override
  bool get isDemo => true;
  final DemoCatalog catalog;
  final DateTime Function() now;
  final List<Map<String, dynamic>> _bookings = [];
  @override
  Future<Map<String, dynamic>> facility(int id) async {
    final f = catalog.facility(id);
    return {
      'id': f.id,
      'name': f.name,
      'address': f.address,
      'photoAsset': f.image,
      'courts': f.courts,
    };
  }

  DemoFacility _owner(int courtId) => catalog.facilities.firstWhere(
    (f) => f.courts.any((c) => c['id'] == courtId),
  );
  int price(int courtId, DateTime start, DateTime end) {
    final f = _owner(courtId);
    final local = start.toUtc().add(const Duration(hours: 7));
    final rate = f.hourlyPrice + (local.hour >= 17 ? 20000 : 0);
    return (rate * end.difference(start).inMinutes / 60).round();
  }

  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async {
    final f = _owner(courtId);
    if (f.id != facilityId) {
      throw StateError('Court does not belong to this facility.');
    }
    return [
      for (var hour = 6; hour < 22; hour++)
        if (!_overlaps(
          courtId,
          DateTime.parse(
            '${date}T${hour.toString().padLeft(2, '0')}:00:00+07:00',
          ),
          DateTime.parse(
            '${date}T${(hour + 1).toString().padLeft(2, '0')}:00:00+07:00',
          ),
        ))
          {
            'id': '$courtId-$date-$hour',
            'startTime': '${hour.toString().padLeft(2, '0')}:00',
            'endTime': '${(hour + 1).toString().padLeft(2, '0')}:00',
            'isActive': true,
            'price': f.hourlyPrice + (hour >= 17 ? 20000 : 0),
          },
    ];
  }

  bool _overlaps(int id, DateTime start, DateTime end) => _bookings.any(
    (b) =>
        b['courtId'] == id &&
        start.isBefore(DateTime.parse(b['endTime'] as String)) &&
        end.isAfter(DateTime.parse(b['startTime'] as String)),
  );
  @override
  Future<Map<String, dynamic>> book({
    int? facilityId,
    required int courtId,
    required String startTime,
    required String endTime,
  }) async {
    final f = _owner(courtId);
    if (facilityId != null && facilityId != f.id) {
      throw StateError('Court does not belong to this demo facility.');
    }
    final start = DateTime.parse(startTime), end = DateTime.parse(endTime);
    final localStart = start.toUtc().add(const Duration(hours: 7));
    final localEnd = end.toUtc().add(const Duration(hours: 7));
    if (!start.isAfter(now()) ||
        end.difference(start) != const Duration(hours: 1) ||
        localStart.hour < 6 ||
        localStart.hour >= 22 ||
        localStart.second != 0 ||
        localEnd.hour > 22 ||
        localStart.minute != 0 ||
        _overlaps(courtId, start, end)) {
      throw StateError(
        'This demo slot is unavailable. Please choose another time.',
      );
    }
    final result = <String, dynamic>{
      'id': 'DEMO-${_bookings.length + 1}',
      'courtId': courtId,
      'startTime': startTime,
      'endTime': endTime,
      'totalPrice': price(courtId, start, end),
      'facilityId': f.id,
      'photoAsset': f.image,
      'demo': true,
    };
    _bookings.add(result);
    return Map.of(result);
  }

  List<BookingHistoryItem> get history => _bookings.reversed.map((b) {
    final f = catalog.facility(b['facilityId'] as int);
    final court = f.courts.firstWhere((c) => c['id'] == b['courtId']);
    return BookingHistoryItem(
      source: {
        ...b,
        'status': 'CONFIRMED',
        'court': {
          ...court,
          'facility': {'name': f.name, 'address': f.address},
        },
      },
      id: b['id'] as String,
      facilityName: f.name,
      courtName: court['name'] as String,
      dateTimeText: '${b['startTime']} – ${b['endTime']}',
      priceText: '${b['totalPrice']} VND',
      status: BookingStatus.upcoming,
    );
  }).toList();
}

final demoBookingProvider = Provider<DemoBookingService>(
  (ref) => DemoBookingService(ref.watch(demoCatalogProvider)),
);
