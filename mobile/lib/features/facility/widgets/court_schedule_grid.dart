import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

enum SlotStatus { available, booked, locked, event }

class CourtScheduleGrid extends StatefulWidget {
  final int courtCount;
  final List<String>? courtNames;
  final Function(int courtIndex, int timeIndex)? onSlotSelected;

  const CourtScheduleGrid({
    super.key,
    this.courtCount = 4,
    this.courtNames,
    this.onSlotSelected,
  });

  @override
  State<CourtScheduleGrid> createState() => _CourtScheduleGridState();
}

class _CourtScheduleGridState extends State<CourtScheduleGrid> {
  final List<String> timeLabels = [
    '17:00',
    '17:30',
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
    '21:00',
  ];

  int? selectedCourtIndex = 0;
  int? selectedTimeIndex = 1;

  // Ma trận mẫu slot sân x 9 mốc giờ
  late List<List<SlotStatus>> matrix;

  @override
  void initState() {
    super.initState();
    _initMatrix();
  }

  @override
  void didUpdateWidget(covariant CourtScheduleGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courtCount != widget.courtCount) {
      setState(() {
        _initMatrix();
        if (selectedCourtIndex != null &&
            selectedCourtIndex! >= widget.courtCount) {
          selectedCourtIndex = widget.courtCount > 0 ? 0 : null;
        }
      });
    }
  }

  void _initMatrix() {
    final count = widget.courtCount > 0 ? widget.courtCount : 4;
    matrix = List.generate(
      count,
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
          width: double.infinity,
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
                    width: 32,
                  ), // Khoảng trống cho tên sân bên trái
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: timeLabels
                          .map(
                            (time) => Expanded(
                              child: SizedBox(
                                child: Text(
                                  time,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
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

              // Danh sách hàng sân
              ...List.generate(widget.courtCount, (courtIdx) {
                final courtLabel =
                    (widget.courtNames != null &&
                        courtIdx < widget.courtNames!.length)
                    ? widget.courtNames![courtIdx]
                    : 'Court ${courtIdx + 1}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          courtLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            final status =
                                (courtIdx < matrix.length &&
                                    timeIdx < matrix[courtIdx].length)
                                ? matrix[courtIdx][timeIdx]
                                : SlotStatus.available;
                            final isSelected =
                                selectedCourtIndex == courtIdx &&
                                selectedTimeIndex == timeIdx;

                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(1),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedCourtIndex = courtIdx;
                                      selectedTimeIndex = timeIdx;
                                    });
                                    widget.onSlotSelected?.call(
                                      courtIdx,
                                      timeIdx,
                                    );
                                  },
                                  child: Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      color: _getSlotColor(status),
                                      borderRadius: BorderRadius.circular(2),
                                      border: isSelected
                                          ? Border.all(
                                              color:
                                                  AppColors.slotBorderSelected,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                  ),
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
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
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
