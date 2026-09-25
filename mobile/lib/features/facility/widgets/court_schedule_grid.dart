import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

enum SlotStatus { available, booked, locked, event }

class CourtScheduleGrid extends StatefulWidget {
  final int courtCount;
  final Function(int courtIndex, int timeIndex)? onSlotSelected;

  const CourtScheduleGrid({
    super.key,
    this.courtCount = 6,
    this.onSlotSelected,
  });

  @override
  State<CourtScheduleGrid> createState() => _CourtScheduleGridState();
}

class _CourtScheduleGridState extends State<CourtScheduleGrid> {
  final List<String> timeLabels = [
    '06:00',
    '08:00',
    '10:00',
    '12:00',
    '14:00',
    '16:00',
    '18:00',
    '20:00',
    '21:00',
  ];

  int? selectedCourtIndex = 0;
  int? selectedTimeIndex = 1;

  // Ma trận mẫu slot 6 sân x 9 mốc giờ
  late List<List<SlotStatus>> matrix;

  @override
  void initState() {
    super.initState();
    _initMatrix();
  }

  void _initMatrix() {
    matrix = List.generate(
      widget.courtCount,
      (c) => List.generate(9, (t) {
        if ((c + t) % 5 == 0) return SlotStatus.booked;
        if ((c * 2 + t) % 7 == 0) return SlotStatus.locked;
        if (c == 2 && t >= 6) return SlotStatus.event;
        return SlotStatus.available;
      }),
    );
  }

  Color _getSlotColor(SlotStatus status) {
    switch (status) {
      case SlotStatus.available:
        return AppColors.slotAvailableLight;
      case SlotStatus.booked:
        return AppColors.slotBooked;
      case SlotStatus.locked:
        return AppColors.slotLocked;
      case SlotStatus.event:
        return AppColors.slotEvent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid Container
        Container(
          width: 345,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              // Hàng Header Time Labels
              Row(
                children: [
                  const SizedBox(
                    width: 55,
                  ), // Khoảng trống cho tên sân bên trái
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: timeLabels
                          .map(
                            (time) => SizedBox(
                              width: 25,
                              child: Text(
                                time.split(':')[0], // Chỉ hiện 06, 08...
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 6 Hàng sân
              ...List.generate(widget.courtCount, (courtIdx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 55,
                        child: Text(
                          'Court ${courtIdx + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(9, (timeIdx) {
                            final status = matrix[courtIdx][timeIdx];
                            final isSelected =
                                selectedCourtIndex == courtIdx &&
                                selectedTimeIndex == timeIdx;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCourtIndex = courtIdx;
                                  selectedTimeIndex = timeIdx;
                                });
                                widget.onSlotSelected?.call(courtIdx, timeIdx);
                              },
                              child: Container(
                                width: 25,
                                height: 25,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.slotAvailable
                                      : _getSlotColor(status),
                                  borderRadius: BorderRadius.circular(2),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.slotBorderSelected,
                                          width: 2,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Legend (Chú thích trạng thái)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem('Available', AppColors.slotAvailableLight),
              _buildLegendItem('Booked', AppColors.slotBooked),
              _buildLegendItem('Locked', AppColors.slotLocked),
              _buildLegendItem('Event', AppColors.slotEvent),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
