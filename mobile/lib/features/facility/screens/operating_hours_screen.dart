import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lưu giờ mở cửa thành công!')),
                  );
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: Text(
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

  Widget _buildDayRow(DaySchedule schedule) {
    return Container(
      width: double.infinity,
      height: 58,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tên thứ & Toggle Switch
          Row(
            children: [
              SizedBox(
                height: 30,
                child: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: schedule.isOpen,
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.mintLight,
                    onChanged: (val) {
                      setState(() {
                        schedule.isOpen = val;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 75,
                child: Text(
                  schedule.dayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: schedule.isOpen
                        ? AppColors.textDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Giờ hoạt động (Start - End) hoặc chữ "Closed"
          if (schedule.isOpen)
            Row(
              children: [
                _buildTimeBox(
                  schedule.openTime,
                  () => _pickTime(context, schedule, true),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _buildTimeBox(
                  schedule.closeTime,
                  () => _pickTime(context, schedule, false),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Closed',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.linkAction,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.mintBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(
          time,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
        ),
      ),
    );
  }
}
