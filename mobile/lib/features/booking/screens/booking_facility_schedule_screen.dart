import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../booking_theme.dart';

enum SlotStatus { available, booked, locked, event }

class BookingFacilityScheduleScreen extends StatefulWidget {
  final VoidCallback? onContinue;

  const BookingFacilityScheduleScreen({super.key, this.onContinue});

  @override
  State<BookingFacilityScheduleScreen> createState() =>
      _BookingFacilityScheduleScreenState();
}

class _BookingFacilityScheduleScreenState
    extends State<BookingFacilityScheduleScreen> {
  int _activeTab = 0; // 0: Court Schedule, 1: Facility Info
  final String _selectedDate = '20/09/2026 (Today)';

  // Danh sách 9 mốc giờ (17:00 đến 21:00, bước 30 phút)
  final List<String> _timeSlots = [
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

  // 6 Sân
  final List<String> _courts = [
    'Sân 1',
    'Sân 2',
    'Sân 3',
    'Sân 4',
    'Sân 5',
    'Sân 6',
  ];

  // Slot được chọn: Mặc định theo Figma là Sân 3 (index 2), slot 19:00 (index 4)
  int _selectedCourtIndex = 2;
  int _selectedSlotIndex = 4;

  // Ma trận trạng thái (6 sân x 9 slot) mô phỏng đúng bố cục Figma
  late List<List<SlotStatus>> _gridStatus;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _gridStatus = [
      // Sân 1
      [
        SlotStatus.booked,
        SlotStatus.booked,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.locked,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.booked,
      ],
      // Sân 2
      [
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.event,
        SlotStatus.event,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.booked,
        SlotStatus.available,
      ],
      // Sân 3 (Figma chọn Sân 3 lúc 19:00)
      [
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.available, // 19:00 - selected
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.available,
        SlotStatus.available,
      ],
      // Sân 4
      [
        SlotStatus.locked,
        SlotStatus.locked,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.booked,
        SlotStatus.available,
        SlotStatus.available,
      ],
      // Sân 5
      [
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.booked,
        SlotStatus.available,
        SlotStatus.event,
        SlotStatus.event,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.locked,
      ],
      // Sân 6
      [
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.locked,
        SlotStatus.available,
        SlotStatus.available,
        SlotStatus.booked,
        SlotStatus.booked,
        SlotStatus.available,
      ],
    ];
  }

  Color _getSlotColor(SlotStatus status) {
    switch (status) {
      case SlotStatus.available:
        return BookingColors.slotAvailable;
      case SlotStatus.booked:
        return BookingColors.slotBooked;
      case SlotStatus.locked:
        return BookingColors.slotLocked;
      case SlotStatus.event:
        return BookingColors.slotEvent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 16),
              _buildHeroSection(),
              const SizedBox(height: 14),
              _buildFacilityHeader(),
              const SizedBox(height: 8),
              _buildLocationAndDesc(),
              const SizedBox(height: 16),
              _buildStatCards(),
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 12),
              _buildDateSelector(),
              const SizedBox(height: 12),
              _buildScheduleGrid(),
              const SizedBox(height: 12),
              _buildLegend(),
              const SizedBox(height: 14),
              _buildSelectedSlotBar(),
              const SizedBox(height: 14),
              _buildContinueButton(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Top Bar
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BookingColors.cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: BookingColors.border),
            ),
            child: SvgPicture.asset(
              BookingIcons.facilityBack,
              width: 18,
              height: 18,
            ),
          ),
        ),
        Row(
          children: [
            InkWell(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BookingColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: BookingColors.border),
                ),
                child: SvgPicture.asset(
                  BookingIcons.favoriteOutline,
                  width: 18,
                  height: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BookingColors.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: BookingColors.border),
                ),
                child: SvgPicture.asset(
                  BookingIcons.facilityMore,
                  width: 18,
                  height: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2. Hero Vector Banner + Badge 1/5
  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      height: 108,
      decoration: BoxDecoration(
        color: const Color(0xFF034D3F),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              BookingIcons.courtPattern,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: BookingColors.primaryPressed.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1/5',
                style: BookingTypography.jakarta(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Tên sân & Badge Open
  Widget _buildFacilityHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Sunrise Badminton Club',
            style: BookingTypography.jakarta(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BookingColors.textDarkM1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: BookingColors.badgeUpcomingBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: BookingColors.slotAvailable,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Open',
                style: BookingTypography.jakarta(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BookingColors.badgeUpcomingText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Địa chỉ và mô tả
  Widget _buildLocationAndDesc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SvgPicture.asset(
              BookingIcons.facilityLocation,
              width: 14,
              height: 14,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '123 Le Van Viet, D9, HCMC',
                style: BookingTypography.jakarta(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: BookingColors.textSecondaryM1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Standard badminton facility with international flooring and modern lighting.',
          style: BookingTypography.jakarta(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: BookingColors.textSecondaryM1,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // 5. 3 Stat Cards
  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSingleStatCard(
            icon: BookingIcons.statCourt,
            title: '6 Courts',
            subtitle: 'Court Count',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleStatCard(
            icon: BookingIcons.clock,
            title: '06:00 – 22:00',
            subtitle: 'Operating Hours',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSingleStatCard(
            icon: BookingIcons.indoor,
            title: 'Indoor',
            subtitle: 'Facility Type',
          ),
        ),
      ],
    );
  }

  Widget _buildSingleStatCard({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingColors.borderStat),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(icon, width: 16, height: 16),
          const SizedBox(height: 4),
          Text(
            title,
            style: BookingTypography.jakarta(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: BookingColors.textDarkM1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: BookingTypography.jakarta(
              fontSize: 10,
              fontWeight: FontWeight.w400,
              color: BookingColors.textSecondaryM1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 6. Tabs
  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8E4), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 0),
              child: Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 0
                          ? BookingColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Court Schedule',
                    style: BookingTypography.jakarta(
                      fontSize: 13,
                      fontWeight: _activeTab == 0
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _activeTab == 0
                          ? BookingColors.primary
                          : BookingColors.textSecondaryM1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = 1),
              child: Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _activeTab == 1
                          ? BookingColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Facility Info',
                    style: BookingTypography.jakarta(
                      fontSize: 13,
                      fontWeight: _activeTab == 1
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: _activeTab == 1
                          ? BookingColors.primary
                          : BookingColors.textSecondaryM1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 7. Date Selector
  Widget _buildDateSelector() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingColors.borderStat),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {},
            child: const Icon(
              Icons.chevron_left,
              size: 20,
              color: BookingColors.textDarkM1,
            ),
          ),
          Text(
            _selectedDate,
            style: BookingTypography.jakarta(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BookingColors.textDarkM1,
            ),
          ),
          InkWell(
            onTap: () {},
            child: const Icon(
              Icons.chevron_right,
              size: 20,
              color: BookingColors.textDarkM1,
            ),
          ),
        ],
      ),
    );
  }

  // 8. Schedule Grid (6 sân x 9 khung giờ)
  Widget _buildScheduleGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BookingColors.borderStat),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Giờ
            Row(
              children: [
                const SizedBox(width: 48), // Chỗ cho nhãn Sân
                ...List.generate(_timeSlots.length, (index) {
                  return Container(
                    width: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    alignment: Alignment.center,
                    child: Text(
                      _timeSlots[index],
                      style: BookingTypography.jakarta(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: BookingColors.textSecondaryM1,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            // Các hàng Sân 1 -> Sân 6
            ...List.generate(_courts.length, (cIdx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        _courts[cIdx],
                        style: BookingTypography.jakarta(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: BookingColors.textDarkM1,
                        ),
                      ),
                    ),
                    ...List.generate(_timeSlots.length, (sIdx) {
                      final status = _gridStatus[cIdx][sIdx];
                      final isSelected =
                          _selectedCourtIndex == cIdx &&
                          _selectedSlotIndex == sIdx;

                      return GestureDetector(
                        onTap: () {
                          if (status == SlotStatus.available) {
                            setState(() {
                              _selectedCourtIndex = cIdx;
                              _selectedSlotIndex = sIdx;
                            });
                          }
                        },
                        child: Container(
                          width: 32,
                          height: 25,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? BookingColors.primary
                                : _getSlotColor(status),
                            borderRadius: BorderRadius.circular(2),
                            border: isSelected
                                ? Border.all(
                                    color: BookingColors.slotSelectedBorder,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // 9. Legend
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLegendItem('Trống', BookingColors.slotAvailable),
        _buildLegendItem('Đã đặt', BookingColors.slotBooked),
        _buildLegendItem('Khoá', BookingColors.slotLocked),
        _buildLegendItem('Sự kiện', BookingColors.slotEvent),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          style: BookingTypography.jakarta(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: BookingColors.textSecondaryM1,
          ),
        ),
      ],
    );
  }

  // 10. Selected Slot Bar
  Widget _buildSelectedSlotBar() {
    final courtName = _courts[_selectedCourtIndex];
    final slotTime = _timeSlots[_selectedSlotIndex];
    // Tính khung 30 phút tiếp theo
    final nextSlot = _selectedSlotIndex + 1 < _timeSlots.length
        ? _timeSlots[_selectedSlotIndex + 1]
        : '21:30';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: BookingColors.termsBoxBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BookingColors.borderStat),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                '$courtName · $slotTime–$nextSlot',
                style: BookingTypography.jakarta(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BookingColors.textDarkM1,
                ),
              ),
            ],
          ),
          Text(
            '100,000 VND',
            style: BookingTypography.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BookingColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // 11. Continue Button
  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: BookingColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        onPressed: () {
          if (widget.onContinue != null) {
            widget.onContinue!();
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: BookingTypography.jakarta(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            SvgPicture.asset(
              BookingIcons.continueArrow,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
