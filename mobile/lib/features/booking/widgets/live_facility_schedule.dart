import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../court_map/facility_images.dart';
import '../../court_map/exploration_data.dart';
import '../../court_map/widgets/facility_gallery.dart';
import '../../court_map/widgets/facility_services.dart';

import '../../../core/theme/app_motion.dart';
import '../booking_theme.dart';
import '../services/live_booking_service.dart';
import '../screens/booking_summary_screen.dart';
import '../screens/booking_success_screen.dart';
import '../screens/booking_history_screen.dart';

/// Live content of the existing schedule screen; preview content is preserved.
class LiveFacilitySchedule extends StatefulWidget {
  const LiveFacilitySchedule({
    super.key,
    required this.facilityId,
    this.initialCourtId,
    this.service,
    this.now,
    this.demo = false,
    this.onViewBookings,
    this.onBackHome,
  });
  final int facilityId;
  final int? initialCourtId;
  final bool demo;
  final VoidCallback? onViewBookings;
  final VoidCallback? onBackHome;
  final LiveBookingService? service;
  final DateTime Function()? now;
  @override
  State<LiveFacilitySchedule> createState() => _LiveFacilityScheduleState();
}

class _LiveFacilityScheduleState extends State<LiveFacilitySchedule> {
  late final service = widget.service ?? LiveBookingService();
  Map<String, dynamic>? facility;
  List<Map<String, dynamic>> courts = [];
  Map<int, List<Map<String, dynamic>>> slotsByCourt = {};
  Map<String, dynamic>? selected;
  int? courtId;
  late DateTime date;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  bool loading = true;
  String? error;
  int generation = 0;
  Timer? selectionExpiry;
  final horizontalController = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    selectionExpiry?.cancel();
    horizontalController.dispose();
    super.dispose();
  }

  bool selectable(Map<String, dynamic> slot) =>
      (slot['parts'] != null || bookableDuration(slot)) &&
      future(slot) &&
      (widget.demo || slot['isBooked'] == false) &&
      slot['isBooked'] != true &&
      slot['isActive'] != false &&
      (slot['status'] == null || slot['status'] == 'AVAILABLE') &&
      slot['price'] is num;

  void positionSchedule(int request) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          request != generation ||
          !horizontalController.hasClients) {
        return;
      }
      final columns = timeColumns;
      final next = columns.indexWhere(
        (time) => slotsByCourt.values.any(
          (slots) => slots.any(
            (slot) =>
                '${slot['startTime'].toString().substring(0, 5)} – ${slot['endTime'].toString().substring(0, 5)}' ==
                    time &&
                selectable(slot),
          ),
        ),
      );
      final target = next < 0 ? columns.length - 1 : next;
      horizontalController.jumpTo(
        (target * 60.0).clamp(
          0.0,
          horizontalController.position.maxScrollExtent,
        ),
      );
    });
  }

  String get dateLabel {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool get isToday =>
      DateUtils.isSameDay(date, now.toUtc().add(const Duration(hours: 7)));

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String timestamp(String time) =>
      '${dateKey}T${time.substring(0, 5)}:00+07:00';
  int minute(Object? raw) {
    final parts = raw.toString().split(':');
    if (parts.length < 2) return -10000;
    return (int.tryParse(parts[0]) ?? -1000) * 60 +
        (int.tryParse(parts[1]) ?? -1000);
  }

  bool bookableDuration(Map<String, dynamic> slot) =>
      minute(slot['endTime']) - minute(slot['startTime']) >= 30 &&
      minute(slot['endTime']) - minute(slot['startTime']) <= 60;
  String get bookingUnitLabel {
    final durations =
        slotsByCourt.values
            .expand((slots) => slots)
            .where(bookableDuration)
            .map((slot) => minute(slot['endTime']) - minute(slot['startTime']))
            .toSet()
            .toList()
          ..sort();
    if (durations.isEmpty) return '—';
    if (durations.length == 1) {
      return durations.single == 60 ? '1 hour' : '${durations.single} min';
    }
    return '${durations.first}–${durations.last} min';
  }

  List<String> get photos => FacilityImages.resolve(
    name: facility?['name']?.toString() ?? '',
    address: facility?['address']?.toString() ?? '',
    photos:
        (facility?['photos'] as List?)?.whereType<String>().toList() ??
        [
          if (facility?['photoAsset'] is String)
            facility!['photoAsset'] as String,
        ],
  );
  String? get photo => photos.isEmpty ? null : photos.first;
  bool future(Map<String, dynamic> slot) =>
      DateTime.tryParse(timestamp(slot['startTime'].toString()))
          ?.isAfter(now) ??
      false;
  @override
  void initState() {
    super.initState();
    courtId = widget.initialCourtId;
    date = now.toUtc().add(const Duration(hours: 7));
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    selectionExpiry?.cancel();
    setState(() {
      loading = true;
      error = null;
      selected = null;
    });
    try {
      if (widget.demo != service.isDemo) {
        throw StateError(
          'Demo và API thật phải dùng đúng booking service tương ứng.',
        );
      }
      final f = await service.facility(widget.facilityId);
      if (!mounted || request != generation) return;
      final available = (f['courts'] as List? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) => c['status'] == 'ACTIVE')
          .toList();
      if (courtId != null && !available.any((c) => c['id'] == courtId)) {
        throw StateError('Sân đã chọn không còn hoạt động tại cơ sở này.');
      }
      final id = available.any((c) => c['id'] == courtId)
          ? courtId
          : available.isEmpty
          ? null
          : (available.first['id'] as num).toInt();
      final rows = await Future.wait(
        available.map((court) async {
          final courtId = (court['id'] as num).toInt();
          return MapEntry(
            courtId,
            await service.slots(widget.facilityId, courtId, dateKey),
          );
        }),
      );
      if (!mounted || request != generation) return;
      setState(() {
        facility = f;
        courts = available;
        courtId = id;
        slotsByCourt = Map.fromEntries(rows);
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error = 'Could not load court availability. Tap to retry.',
        );
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => loading = false);
        if (error == null) positionSchedule(request);
      }
    }
  }

  Future<void> pickDate() async {
    final today = DateUtils.dateOnly(now.toUtc().add(const Duration(hours: 7)));
    var picked = date.isBefore(today) ? today : date;
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (sheetContext) => Container(
        height: 330,
        color: BookingColors.background,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext, picked),
                    child: const Text('Done'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: DateUtils.dateOnly(picked),
                  minimumDate: today,
                  maximumDate: today.add(const Duration(days: 365)),
                  onDateTimeChanged: (value) => picked = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    date = result;
    await load();
  }

  Future<void> review() async {
    final slot = selected;
    final id = courtId;
    final f = facility;
    if (slot == null || id == null || f == null || !selectable(slot)) return;
    final start = timestamp(slot['startTime'].toString());
    final end = timestamp(slot['endTime'].toString());
    final court = courts.firstWhere((c) => c['id'] == id);
    final day = dateKey;
    var submitting = false;
    String? submitError;
    var conflicted = false;
    await Navigator.of(context).push(
      AppMotion.route<void>(
        StatefulBuilder(
          builder: (summaryContext, update) => Column(
            children: [
              if (submitError != null)
                SafeArea(
                  bottom: false,
                  child: Material(
                    color: const Color(0xFFFCE6E4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(submitError!),
                    ),
                  ),
                ),
              Expanded(
                child: BookingSummaryScreen(
                  demo: widget.demo,
                  photoAsset: photo,
                  facilityName: f['name'].toString(),
                  courtName: court['name'].toString(),
                  address: f['address']?.toString() ?? '—',
                  dateText: day,
                  timeRange: '${slot['startTime']} – ${slot['endTime']}',
                  durationText:
                      '${DateTime.parse(end).difference(DateTime.parse(start)).inMinutes} minutes',
                  courtType: court['courtType']?.toString() ?? '—',
                  priceText: '${facilityPrice(slot['price'] as num)} VND',
                  isSubmitting: submitting,
                  canConfirm: !conflicted,
                  onConfirm: () async {
                    if (submitting || conflicted) return;
                    update(() {
                      submitting = true;
                      submitError = null;
                    });
                    try {
                      final refreshed = await service.slots(
                        widget.facilityId,
                        id,
                        day,
                      );
                      if (!summaryContext.mounted) return;
                      final parts = (slot['parts'] as List?) ?? [slot];
                      final stillAvailable = parts.every(
                        (part) => refreshed.any(
                          (candidate) =>
                              candidate['startTime'] == part['startTime'] &&
                              candidate['endTime'] == part['endTime'] &&
                              candidate['price'] == part['price'] &&
                              selectable(candidate),
                        ),
                      );
                      if (!stillAvailable) {
                        conflicted = true;
                        selected = null;
                        update(() {
                          submitting = false;
                          submitError = 'Availability or price changed. Go back and select another slot.';
                        });
                        return;
                      }
                      final booking = await service.book(
                        facilityId: widget.facilityId,
                        courtId: id,
                        startTime: start,
                        endTime: end,
                      );
                      if (!summaryContext.mounted) return;
                      Navigator.of(summaryContext).pushReplacement(
                        AppMotion.route<void>(
                          BookingSuccessScreen(
                            demo: widget.demo,
                            photoAsset: photo,
                            bookingId: booking['id'].toString(),
                            facilityName: f['name'].toString(),
                            courtName: court['name'].toString(),
                            address: f['address']?.toString() ?? '—',
                            dateTimeText:
                                '$day · ${slot['startTime']}–${slot['endTime']}',
                            totalPrice:
                                '${facilityPrice(booking['totalPrice'] as num)} VND',
                            onViewBookings: () {
                              if (widget.onViewBookings != null) {
                                widget.onViewBookings!();
                                return;
                              }
                              Navigator.of(context).pushReplacement(
                                AppMotion.route<void>(
                                  const BookingHistoryScreen(live: true),
                                ),
                              );
                            },
                            onBackHome:
                                widget.onBackHome ??
                                () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!summaryContext.mounted) return;
                      String message = 'Không đặt được sân. Vui lòng thử lại.';
                      if (e is StateError) message = e.message.toString();
                      if (e is DioException && e.response == null) {
                        message = 'Chưa nhận được xác nhận từ máy chủ. Hãy kiểm tra lịch sử đặt sân trước khi thử lại.';
                      }
                      if (e is DioException && e.response?.statusCode == 409) {
                        conflicted = true;
                        selected = null;
                        message = 'This slot was just booked. Go back and select another time.';
                      } else if (e is DioException && e.response?.data is Map) {
                        final detail = (e.response!.data as Map)['message'];
                        if (detail is String) message = detail;
                      }
                      update(() {
                        submitting = false;
                        submitError = message;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        name: '/live-booking-summary',
      ),
    );
    if (mounted) await load();
  }

  List<String> get timeColumns {
    final times = <String>{};
    for (final entries in slotsByCourt.values) {
      for (final slot in entries) {
        final start = slot['startTime'];
        final end = slot['endTime'];
        if (bookableDuration(slot) &&
            start is String &&
            end is String &&
            start.length >= 5 &&
            end.length >= 5) {
          times.add('${start.substring(0, 5)} – ${end.substring(0, 5)}');
        }
      }
    }
    return times.toList()..sort();
  }

  Widget _grid() {
    final columns = timeColumns;
    if (courts.isEmpty) return const Text('No active courts at this facility.');
    if (columns.isEmpty) {
      return const Text(
        'No booking slots configured for this date. Choose another date.',
      );
    }
    const labelWidth = 52.0;
    const cellWidth = 60.0;
    return Container(
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: Text(
                    'Court',
                    style: BookingTypography.jakarta(
                      fontSize: 11,
                      color: BookingColors.textSecondary,
                    ),
                  ),
                ),
                for (final court in courts)
                  SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        court['name'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BookingTypography.jakarta(
                          fontSize: 11,
                          fontWeight: court['id'] == courtId
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: BookingColors.textDark,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: horizontalController,
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
                              style: BookingTypography.jakarta(
                                fontSize: 11,
                                color: BookingColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final court in courts)
                    _courtRow(court, columns, cellWidth),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _courtRow(
    Map<String, dynamic> court,
    List<String> columns,
    double cellWidth,
  ) {
    final id = (court['id'] as num).toInt();
    final entries = slotsByCourt[id] ?? [];
    return Padding(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          for (final time in columns)
            Builder(
              builder: (context) {
                final matches = entries
                    .where(
                      (slot) =>
                          '${slot['startTime'].toString().substring(0, 5)} – ${slot['endTime'].toString().substring(0, 5)}' ==
                          time,
                    )
                    .toList();
                final slot = matches.length == 1 ? matches.single : null;
                final booked =
                    slot?['status'] == 'BOOKED' || slot?['isBooked'] == true;
                final event = slot?['status'] == 'EVENT';
                final available =
                    slot != null &&
                    !booked &&
                    slot['isActive'] != false &&
                    (slot['status'] == null || slot['status'] == 'AVAILABLE') &&
                    (widget.demo || slot['isBooked'] == false);
                final past = available && !future(slot);
                final canSelect = slot != null && selectable(slot);
                final isSelected =
                    canSelect &&
                    id == courtId &&
                    minute(slot['startTime']) >=
                        minute(selected?['startTime']) &&
                    minute(slot['endTime']) <= minute(selected?['endTime']) &&
                    selected != null;
                final color = isSelected
                    ? BookingColors.primary
                    : booked
                    ? BookingColors.slotBooked
                    : event
                    ? BookingColors.slotEvent
                    : available
                    ? Colors.white
                    : slot == null
                    ? Colors.transparent
                    : BookingColors.slotLocked;
                return SizedBox(
                  height: 44,
                  width: cellWidth,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 0 : 3,
                      vertical: 2,
                    ),
                    child: Semantics(
                      button: true,
                      enabled: canSelect,
                      selected: isSelected,
                      label:
                          '${court['name']} · $time · ${booked
                              ? 'Booked'
                              : past
                              ? 'Past; no booking'
                              : event
                              ? 'Event'
                              : canSelect
                              ? '${slot['price']} VND'
                              : available
                              ? 'Available; booking unavailable'
                              : 'Unavailable'}',
                      child: InkWell(
                        key: ValueKey('slot-$id-$time'),
                        onTap: canSelect
                            ? () => setState(() {
                                selectionExpiry?.cancel();
                                final previous = selected;
                                final sameCourt =
                                    courtId == id && previous != null;
                                final from = sameCourt
                                    ? (minute(previous['startTime']) <
                                              minute(slot['startTime'])
                                          ? previous['startTime']
                                          : slot['startTime'])
                                    : slot['startTime'];
                                final to = sameCourt
                                    ? (minute(previous['endTime']) >
                                              minute(slot['endTime'])
                                          ? previous['endTime']
                                          : slot['endTime'])
                                    : slot['endTime'];
                                final parts =
                                    entries
                                        .where(
                                          (entry) =>
                                              minute(entry['startTime']) >=
                                                  minute(from) &&
                                              minute(entry['endTime']) <=
                                                  minute(to),
                                        )
                                        .toList()
                                      ..sort(
                                        (a, b) => minute(a['startTime'])
                                            .compareTo(minute(b['startTime'])),
                                      );
                                var cursor = minute(from);
                                var valid = parts.isNotEmpty;
                                for (final part in parts) {
                                  if (!selectable(part) ||
                                      minute(part['startTime']) != cursor) {
                                    valid = false;
                                  }
                                  cursor = minute(part['endTime']);
                                }
                                valid = valid && cursor == minute(to);
                                courtId = id;
                                // Tapping inside the current range clears it.
                                selected = isSelected
                                    ? null
                                    : valid
                                    ? {
                                        ...slot,
                                        'startTime': from,
                                        'endTime': to,
                                        'price': parts.fold<num>(
                                          0,
                                          (total, part) =>
                                              total + (part['price'] as num),
                                        ),
                                        'parts': parts,
                                      }
                                    : {
                                        ...slot,
                                        'parts': [slot],
                                      };
                                if (selected != null) {
                                  final startsAt = DateTime.parse(
                                    timestamp(
                                      selected!['startTime'].toString(),
                                    ),
                                  );
                                  selectionExpiry = Timer(
                                    startsAt.difference(now),
                                    () {
                                      if (mounted) {
                                        setState(() => selected = null);
                                      }
                                    },
                                  );
                                }
                              })
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: isSelected
                                ? BorderRadius.horizontal(
                                    left:
                                        slot['startTime'] ==
                                            selected?['startTime']
                                        ? const Radius.circular(8)
                                        : Radius.zero,
                                    right:
                                        slot['endTime'] == selected?['endTime']
                                        ? const Radius.circular(8)
                                        : Radius.zero,
                                  )
                                : BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: BookingColors.slotSelectedBorder,
                                    width: 1,
                                  )
                                : available
                                ? Border.all(color: BookingColors.borderLight)
                                : null,
                          ),
                          child: isSelected
                              ? const SizedBox.shrink()
                              : available
                              ? const SizedBox.shrink()
                              : Text(
                                  booked
                                      ? 'Booked'
                                      : event
                                      ? 'Event'
                                      : slot == null
                                      ? '—'
                                      : 'Locked',
                                  maxLines: 1,
                                  style: BookingTypography.jakarta(
                                    fontSize: 9,
                                    color: isSelected
                                        ? Colors.white
                                        : BookingColors.textDark,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _legend() => Wrap(
    spacing: 14,
    runSpacing: 8,
    children: [
      _legendItem('Available', Colors.white),
      _legendItem('Selected', BookingColors.primary),
      _legendItem('Booked', BookingColors.slotBooked),
      _legendItem('Locked', BookingColors.slotLocked),
      _legendItem('Event', BookingColors.slotEvent),
    ],
  );

  Widget _legendItem(String label, Color color) => Row(
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
      Text(
        label,
        style: BookingTypography.jakarta(
          fontSize: 11,
          color: BookingColors.textSecondary,
        ),
      ),
    ],
  );

  Widget _stat(String value, String caption) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5.5, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: BookingTypography.jakarta(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: BookingTypography.jakarta(
              fontSize: 10,
              color: BookingColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BookingColors.background,
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: BookingColors.background,
      title: const Text('Booking Schedule'),
      actions: [
        IconButton(
          tooltip: 'Refresh availability',
          onPressed: loading ? null : load,
          icon: const Icon(
            CupertinoIcons.refresh,
            color: BookingColors.primary,
          ),
        ),
      ],
      titleTextStyle: BookingTypography.jakarta(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Icon(
          CupertinoIcons.chevron_left,
          color: BookingColors.primary,
          size: 20,
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: BookingColors.borderStat),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 18,
                      color: BookingColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${courts.firstWhere((court) => court['id'] == courtId)['name']} · ${selected!['startTime']}–${selected!['endTime']}',
                        maxLines: 2,
                        style: BookingTypography.jakarta(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${facilityPrice(selected!['price'] as num)} VND',
                      style: BookingTypography.jakarta(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: BookingColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            if (selected == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Choose consecutive time slots on one court.',
                  style: BookingTypography.jakarta(
                    fontSize: 11,
                    color: BookingColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('booking-continue'),
              onPressed: selected == null || loading || !selectable(selected!)
                  ? null
                  : review,
              style: FilledButton.styleFrom(
                backgroundColor: BookingColors.primary,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    ),
    body: loading
        ? const Center(child: CupertinoActivityIndicator())
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text(error!)),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (photo != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(height: 74, child: FacilityPhoto(photo!)),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  facility?['name']?.toString() ?? '',
                  style: BookingTypography.jakarta(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  facility?['address']?.toString() ?? '',
                  style: BookingTypography.jakarta(
                    fontSize: 12,
                    color: BookingColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat(
                      '${courts.length}',
                      courts.every((c) => c['courtType'] == 'INDOOR')
                          ? 'Indoor courts'
                          : 'Active courts',
                    ),
                    const SizedBox(width: 8),
                    if (facility != null) ...[
                      _stat(
                        CourtLocation.fromJson(facility!).operatingHoursText ??
                            '—',
                        'Opening hours',
                      ),
                      const SizedBox(width: 8),
                    ],
                    _stat(bookingUnitLabel, 'Per booking unit'),
                  ],
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CupertinoButton(
                    onPressed: pickDate,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 20,
                          color: BookingColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: BookingTypography.jakarta(fontSize: 12),
                          ),
                        ),
                        Text(
                          isToday ? 'Today' : 'Change',
                          style: BookingTypography.jakarta(
                            fontSize: 11,
                            color: BookingColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _grid(),
                const SizedBox(height: 12),
                _legend(),
                if (isToday)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Past hours cannot be booked. Times are shown in Vietnam time (UTC+7).',
                      style: BookingTypography.jakarta(
                        fontSize: 11,
                        color: BookingColors.textSecondary,
                      ),
                    ),
                  ),
                if (widget.demo)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Demo only. This booking is stored in this app session and does not reserve a real court.',
                    ),
                  ),
              ],
            ),
          ),
  );
}
