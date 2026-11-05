import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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
    this.service,
    this.now,
  });
  final int facilityId;
  final LiveBookingService? service;
  final DateTime Function()? now;
  @override
  State<LiveFacilitySchedule> createState() => _LiveFacilityScheduleState();
}

class _LiveFacilityScheduleState extends State<LiveFacilitySchedule> {
  late final service = widget.service ?? LiveBookingService();
  Map<String, dynamic>? facility;
  List<Map<String, dynamic>> courts = [], slots = [];
  Map<String, dynamic>? selected;
  int? courtId;
  late DateTime date;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  bool loading = true;
  String? error;
  int generation = 0;

  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String timestamp(String time) =>
      '${dateKey}T${time.substring(0, 5)}:00+07:00';
  bool future(Map<String, dynamic> slot) =>
      DateTime.tryParse(timestamp(slot['startTime'].toString()))
          ?.isAfter(now) ??
      false;
  @override
  void initState() {
    super.initState();
    date = now.toUtc().add(const Duration(hours: 7));
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      selected = null;
    });
    try {
      final f = await service.facility(widget.facilityId);
      if (!mounted || request != generation) return;
      final available = (f['courts'] as List? ?? [])
          .map((c) => Map<String, dynamic>.from(c as Map))
          .where((c) => c['status'] == 'ACTIVE')
          .toList();
      final id = available.any((c) => c['id'] == courtId)
          ? courtId
          : available.isEmpty
          ? null
          : (available.first['id'] as num).toInt();
      final rows = id == null
          ? <Map<String, dynamic>>[]
          : await service.slots(widget.facilityId, id, dateKey);
      if (!mounted || request != generation) return;
      setState(() {
        facility = f;
        courts = available;
        courtId = id;
        slots = rows.where((s) => s['isActive'] != false && future(s)).toList();
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() => error = 'Không tải được lịch sân. Vui lòng thử lại.');
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> pickDate() async {
    final today = DateUtils.dateOnly(now.toUtc().add(const Duration(hours: 7)));
    final result = await showDatePicker(
      context: context,
      initialDate: date.isBefore(today) ? today : date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (result == null || !mounted) return;
    date = result;
    await load();
  }

  Future<void> review() async {
    final slot = selected;
    final id = courtId;
    final f = facility;
    if (slot == null || id == null || f == null) return;
    final start = timestamp(slot['startTime'].toString());
    final end = timestamp(slot['endTime'].toString());
    final court = courts.firstWhere((c) => c['id'] == id);
    final day = dateKey;
    var submitting = false;
    String? submitError;
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
                  facilityName: f['name'].toString(),
                  courtName: court['name'].toString(),
                  address: f['address']?.toString() ?? '—',
                  dateText: day,
                  timeRange: '${slot['startTime']} – ${slot['endTime']}',
                  durationText:
                      '${DateTime.parse(end).difference(DateTime.parse(start)).inMinutes} minutes',
                  courtType: court['courtType']?.toString() ?? '—',
                  priceText: 'Giá do hệ thống xác nhận',
                  isSubmitting: submitting,
                  onConfirm: () async {
                    if (submitting) return;
                    update(() {
                      submitting = true;
                      submitError = null;
                    });
                    try {
                      final booking = await service.book(
                        courtId: id,
                        startTime: start,
                        endTime: end,
                      );
                      if (!summaryContext.mounted) return;
                      Navigator.of(summaryContext).pushReplacement(
                        AppMotion.route<void>(
                          BookingSuccessScreen(
                            bookingId: booking['id'].toString(),
                            facilityName: f['name'].toString(),
                            courtName: court['name'].toString(),
                            address: f['address']?.toString() ?? '—',
                            dateTimeText:
                                '$day · ${slot['startTime']}–${slot['endTime']}',
                            totalPrice: '${booking['totalPrice']} VND',
                            onViewBookings: () {
                              Navigator.of(context).pushReplacement(
                                AppMotion.route<void>(
                                  const BookingHistoryScreen(live: true),
                                ),
                              );
                            },
                            onBackHome: () => Navigator.of(context).pop(),
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!summaryContext.mounted) return;
                      String message = 'Không đặt được sân. Vui lòng thử lại.';
                      if (e is StateError) message = e.message.toString();
                      if (e is DioException && e.response?.statusCode == 409) {
                        message = 'Khung giờ vừa có người đặt. Vui lòng quay lại chọn giờ khác.';
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BookingColors.background,
    appBar: AppBar(
      title: Text(facility?['name']?.toString() ?? 'Court Schedule'),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: selected == null || loading ? null : review,
          style: FilledButton.styleFrom(
            backgroundColor: BookingColors.primary,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Continue'),
        ),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text(error!)),
          )
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                OutlinedButton.icon(
                  onPressed: pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(dateKey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: courts
                      .map(
                        (c) => ChoiceChip(
                          label: Text(c['name'].toString()),
                          selected: c['id'] == courtId,
                          onSelected: (_) {
                            courtId = (c['id'] as num).toInt();
                            load();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn khung giờ · Giờ Việt Nam (UTC+7)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hệ thống kiểm tra trùng lịch và tính giá khi bạn xác nhận đặt sân.',
                ),
                const SizedBox(height: 16),
                if (courts.isEmpty)
                  const Text('Cơ sở chưa có sân đang hoạt động.')
                else if (slots.isEmpty)
                  const Text(
                    'Chưa có khung giờ cấu hình cho ngày này. Hãy chọn ngày hoặc sân khác.',
                  ),
                ...slots.map(
                  (s) => Card(
                    child: ListTile(
                      title: Text('${s['startTime']} – ${s['endTime']}'),
                      trailing: selected?['id'] == s['id']
                          ? const Icon(
                              Icons.check_circle,
                              color: BookingColors.primary,
                            )
                          : const Icon(Icons.circle_outlined),
                      onTap: () => setState(() => selected = s),
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}
