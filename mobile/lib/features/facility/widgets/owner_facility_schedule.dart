import 'package:flutter/material.dart';

import '../../booking/booking_theme.dart';
import '../../booking/services/live_booking_service.dart';

/// Read-only occupancy for the owner. Booking mutations remain in the player flow.
class OwnerFacilitySchedule extends StatefulWidget {
  const OwnerFacilitySchedule({
    super.key,
    required this.facilityId,
    required this.courts,
    required this.date,
    this.service,
  });

  final int facilityId;
  final List<Map<String, dynamic>> courts;
  final DateTime date;
  final LiveBookingService? service;

  @override
  State<OwnerFacilitySchedule> createState() => _OwnerFacilityScheduleState();
}

class _OwnerFacilityScheduleState extends State<OwnerFacilitySchedule> {
  late final LiveBookingService service =
      widget.service ?? LiveBookingService();
  Map<int, List<Map<String, dynamic>>> rows = {};
  bool loading = true;
  bool failed = false;
  int generation = 0;

  String get dateKey =>
      '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant OwnerFacilitySchedule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId ||
        oldWidget.courts != widget.courts ||
        !DateUtils.isSameDay(oldWidget.date, widget.date)) {
      load();
    }
  }

  Future<void> load() async {
    final request = ++generation;
    final date = dateKey;
    setState(() {
      loading = true;
      failed = false;
      rows = {};
    });
    try {
      final result = await Future.wait(
        widget.courts.where((court) => court['status'] == 'ACTIVE').map((
          court,
        ) async {
          final id = (court['id'] as num).toInt();
          return MapEntry(id, await service.slots(widget.facilityId, id, date));
        }),
      );
      if (!mounted || request != generation) return;
      setState(() => rows = Map.fromEntries(result));
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() => failed = true);
    } finally {
      if (mounted && request == generation) {
        setState(() => loading = false);
      }
    }
  }

  String? slotTime(Map<String, dynamic> slot) {
    final start = slot['startTime'];
    final end = slot['endTime'];
    if (start is! String ||
        end is! String ||
        start.length < 5 ||
        end.length < 5) {
      return null;
    }
    return '${start.substring(0, 5)} – ${end.substring(0, 5)}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (failed) {
      return TextButton(
        onPressed: load,
        child: const Text('Không tải được lịch sân. Nhấn để thử lại.'),
      );
    }
    if (widget.courts.isEmpty) return const Text('Cơ sở chưa có sân.');
    final columns =
        rows.values
            .expand((slots) => slots)
            .map(slotTime)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    if (columns.isEmpty) {
      return const Text('Không có khung giờ được cấu hình cho ngày này.');
    }

    const cellWidth = 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30, child: Text('Court')),
                  for (final court in widget.courts)
                    SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          court['name']?.toString() ?? '—',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Row(
                        children: [
                          for (final time in columns)
                            SizedBox(
                              width: cellWidth,
                              child: Text(
                                time.split(' – ').first,
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final court in widget.courts)
                      Row(
                        children: [
                          for (final time in columns)
                            _cell(court, time, cellWidth),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _legend('Available', Colors.white),
            _legend('Booked', BookingColors.slotBooked),
            _legend('Locked', BookingColors.slotLocked),
            _legend('Event', BookingColors.slotEvent),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Lịch chỉ xem · giờ Việt Nam (UTC+7).'),
      ],
    );
  }

  Widget _cell(Map<String, dynamic> court, String time, double width) {
    final id = (court['id'] as num).toInt();
    final matches = (rows[id] ?? [])
        .where((slot) => slotTime(slot) == time)
        .toList();
    final slot = matches.length == 1 ? matches.single : null;
    final booked = slot?['isBooked'] == true || slot?['status'] == 'BOOKED';
    final event = !booked && slot?['status'] == 'EVENT';
    final blocked =
        court['status'] != 'ACTIVE' ||
        (slot != null &&
            (slot['isActive'] == false || slot['status'] == 'LOCKED'));
    final available =
        slot != null &&
        !booked &&
        !event &&
        !blocked &&
        slot['isBooked'] == false &&
        (slot['status'] == null || slot['status'] == 'AVAILABLE');
    final state = booked
        ? 'Booked'
        : event
        ? 'Event'
        : blocked
        ? 'Locked'
        : available
        ? 'Available'
        : 'Unavailable';
    final color = booked
        ? BookingColors.slotBooked
        : event
        ? BookingColors.slotEvent
        : blocked
        ? BookingColors.slotLocked
        : available
        ? Colors.white
        : Colors.transparent;
    return SizedBox(
      width: width,
      height: 44,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Semantics(
          label: '${court['name']} · $time · $state',
          child: Container(
            key: ValueKey('owner-slot-$id-$time'),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: available
                  ? Border.all(color: BookingColors.borderStat)
                  : null,
            ),
            child: Text(
              available
                  ? ''
                  : state == 'Unavailable'
                  ? '—'
                  : state,
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: color == Colors.white
              ? Border.all(color: BookingColors.borderStat)
              : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(text),
    ],
  );
}
