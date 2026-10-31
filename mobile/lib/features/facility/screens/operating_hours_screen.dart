import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';

class DaySchedule {
  final String dayName;
  final int dayOfWeek; // 0 = Sunday, 1 = Monday ... 6 = Saturday
  bool isOpen;
  String openTime;
  String closeTime;

  DaySchedule({
    required this.dayName,
    required this.dayOfWeek,
    this.isOpen = true,
    this.openTime = '06:00',
    this.closeTime = '22:00',
  });
}

class OperatingHoursScreen extends StatefulWidget {
  final int facilityId;

  const OperatingHoursScreen({super.key, required this.facilityId});

  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  late List<DaySchedule> _schedules;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _schedules = [
      DaySchedule(
        dayName: 'Monday',
        dayOfWeek: 1,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Tuesday',
        dayOfWeek: 2,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Wednesday',
        dayOfWeek: 3,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Thursday',
        dayOfWeek: 4,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Friday',
        dayOfWeek: 5,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Saturday',
        dayOfWeek: 6,
        isOpen: true,
        openTime: '06:00',
        closeTime: '22:00',
      ),
      DaySchedule(
        dayName: 'Sunday',
        dayOfWeek: 0,
        isOpen: false,
        openTime: '08:00',
        closeTime: '20:00',
      ),
    ];
    _loadExistingHours();
  }

  Future<void> _loadExistingHours() async {
    final data = await FacilityService.instance.getFacilityDetails(
      widget.facilityId,
    );
    if (!mounted || data == null) return;
    if (data['operatingHours'] is List) {
      final hoursList = data['operatingHours'] as List;
      setState(() {
        for (var schedule in _schedules) {
          final match = hoursList.cast<Map<String, dynamic>?>().firstWhere(
            (item) => item?['dayOfWeek'] == schedule.dayOfWeek,
            orElse: () => null,
          );
          if (match != null) {
            schedule.isOpen = true;
            final open = (match['openTime'] as String? ?? '06:00');
            final close = (match['closeTime'] as String? ?? '22:00');
            schedule.openTime = open.length >= 5 ? open.substring(0, 5) : open;
            schedule.closeTime = close.length >= 5
                ? close.substring(0, 5)
                : close;
          } else {
            schedule.isOpen = false;
          }
        }
      });
    }
  }

  void _applyMondayToAll() {
    final monday = _schedules.firstWhere((s) => s.dayOfWeek == 1);
    setState(() {
      for (var schedule in _schedules) {
        if (schedule.dayOfWeek != 0) {
          // Giữ nguyên ngày Chủ Nhật
          schedule.isOpen = monday.isOpen;
          schedule.openTime = monday.openTime;
          schedule.closeTime = monday.closeTime;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã áp dụng giờ Thứ Hai cho các ngày trong tuần!'),
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    DaySchedule schedule,
    bool isStart,
  ) async {
    final initialParts = (isStart ? schedule.openTime : schedule.closeTime)
        .split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(initialParts[0]) ?? 6,
      minute: int.tryParse(initialParts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minuteStr = picked.minute.toString().padLeft(2, '0');
      final formatted = '$hourStr:$minuteStr';

      setState(() {
        if (isStart) {
          schedule.openTime = formatted;
        } else {
          schedule.closeTime = formatted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Operating Hours',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Subtitle hướng dẫn
                Text(
                  'Set the opening hours for your facility',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                // 7 hàng ngày trong tuần (345 x 58 px)
                ..._schedules.map((schedule) => _buildDayRow(schedule)),

                const SizedBox(height: 16),

                // Nút Apply Monday hours (345 x 46 px)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _applyMondayToAll,
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Apply Monday hours to all',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 100), // Khoảng trống cho nút Save
              ],
            ),
          ),

          // Nút Save Hours cố định dưới đáy (345 x 52 px)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_schedules.any(
                          (s) =>
                              s.isOpen &&
                              s.openTime.compareTo(s.closeTime) >= 0,
                        )) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Closing time must be after opening time.',
                              ),
                            ),
                          );
                          return;
                        }
                        final openDays = _schedules
                            .where((s) => s.isOpen)
                            .map(
                              (s) => {
                                'dayOfWeek': s.dayOfWeek,
                                'openTime': s.openTime,
                                'closeTime': s.closeTime,
                              },
                            )
                            .toList();

                        if (openDays.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng mở cửa ít nhất 1 ngày trong tuần',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        final success = await FacilityService.instance
                            .updateOperatingHours(
                              facilityId: widget.facilityId,
                              days: openDays,
                            );

                        if (!context.mounted) return;
                        setState(() => _isLoading = false);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lưu giờ mở cửa thành công!'),
                            ),
                          );
                          Navigator.of(context).pop(true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lưu giờ mở cửa thất bại. Vui lòng thử lại!',
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Save Hours',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(DaySchedule schedule) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEBF0ED)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          children: [
            SizedBox(
              width: 68,
              child: Text(
                schedule.dayName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: AppColors.textDark,
                ),
              ),
            ),
            SizedBox(
              width: 38,
              height: 38,
              child: FittedBox(
                child: CupertinoSwitch(
                  value: schedule.isOpen,
                  activeTrackColor: AppColors.primary,
                  onChanged: (v) => setState(() => schedule.isOpen = v),
                ),
              ),
            ),
          ],
        );
        final times = schedule.isOpen
            ? Row(
                children: [
                  Expanded(
                    child: _buildTimeBox(
                      schedule.openTime,
                      () => _pickTime(context, schedule, true),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '-',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: _buildTimeBox(
                      schedule.closeTime,
                      () => _pickTime(context, schedule, false),
                    ),
                  ),
                ],
              )
            : Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Closed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
        return constraints.maxWidth < 300
            ? Column(children: [identity, const SizedBox(height: 8), times])
            : Row(
                children: [
                  identity,
                  const SizedBox(width: 8),
                  Expanded(child: times),
                ],
              );
      },
    ),
  );

  Widget _buildTimeBox(String time, VoidCallback onTap) => Material(
    color: const Color(0xFFFAFBF9),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 13,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    ),
  );
}
