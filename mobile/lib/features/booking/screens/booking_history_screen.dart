import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../booking_theme.dart';

enum BookingStatus { upcoming, completed, cancelled }

class BookingHistoryItem {
  final String id;
  final String facilityName;
  final String courtName;
  final String dateTimeText;
  final String priceText;
  final BookingStatus status;

  const BookingHistoryItem({
    required this.id,
    required this.facilityName,
    required this.courtName,
    required this.dateTimeText,
    required this.priceText,
    required this.status,
  });
}

class BookingHistoryScreen extends StatefulWidget {
  final ValueChanged<BookingHistoryItem>? onSelectBooking;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateProfile;

  const BookingHistoryScreen({
    super.key,
    this.onSelectBooking,
    this.onNavigateHome,
    this.onNavigateProfile,
  });

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  int _activeTabIndex = 0; // 0: Upcoming, 1: Completed, 2: Cancelled
  int _bottomNavIndex = 1; // 1: Bookings is active

  // Dữ liệu mẫu chuẩn 4 card của Figma
  final List<BookingHistoryItem> _allBookings = const [
    BookingHistoryItem(
      id: '#SM20260920001',
      facilityName: 'Sunrise Badminton Club',
      courtName: 'Sân 3 · Indoor Court',
      dateTimeText: 'Sun, 20 Sep 2026 · 19:00 – 19:30',
      priceText: '100,000 VND',
      status: BookingStatus.upcoming,
    ),
    BookingHistoryItem(
      id: '#SM20260926002',
      facilityName: 'District 9 Badminton Arena',
      courtName: 'Sân 1 · Standard Court',
      dateTimeText: 'Sat, 26 Sep 2026 · 18:00 – 19:00',
      priceText: '160,000 VND',
      status: BookingStatus.upcoming,
    ),
    BookingHistoryItem(
      id: '#SM20260918003',
      facilityName: 'Thu Duc Sport Center',
      courtName: 'Sân 2 · Premium Court',
      dateTimeText: 'Fri, 18 Sep 2026 · 17:00 – 18:30',
      priceText: '180,000 VND',
      status: BookingStatus.completed,
    ),
    BookingHistoryItem(
      id: '#SM20260913004',
      facilityName: 'Sunrise Badminton Club',
      courtName: 'Sân 5 · Indoor Court',
      dateTimeText: 'Sun, 13 Sep 2026 · 20:00 – 21:00',
      priceText: '100,000 VND',
      status: BookingStatus.cancelled,
    ),
  ];

  List<BookingHistoryItem> get _displayedBookings {
    switch (_activeTabIndex) {
      case 0:
        return _allBookings
            .where((b) => b.status == BookingStatus.upcoming)
            .toList();
      case 1:
        return _allBookings
            .where((b) => b.status == BookingStatus.completed)
            .toList();
      case 2:
        return _allBookings
            .where((b) => b.status == BookingStatus.cancelled)
            .toList();
      default:
        return _allBookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'My Bookings',
                style: BookingTypography.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BookingColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildTabs(),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                itemCount: _displayedBookings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final booking = _displayedBookings[index];
                  return _buildBookingCard(booking);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 1. 3 Tab chọn trạng thái (Cao 26px)
  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildTabButton(index: 0, title: 'Upcoming (2)'),
          const SizedBox(width: 8),
          _buildTabButton(index: 1, title: 'Completed'),
          const SizedBox(width: 8),
          _buildTabButton(index: 2, title: 'Cancelled'),
        ],
      ),
    );
  }

  Widget _buildTabButton({required int index, required String title}) {
    final isActive = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? BookingColors.primary : BookingColors.cardBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: isActive ? BookingColors.primary : BookingColors.border,
          ),
        ),
        child: Text(
          title,
          style: BookingTypography.inter(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : BookingColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // 2. Thẻ Booking Card (345×116, shadow nhẹ)
  Widget _buildBookingCard(BookingHistoryItem booking) {
    return InkWell(
      onTap: () {
        if (widget.onSelectBooking != null) {
          widget.onSelectBooking!(booking);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BookingColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BookingColors.borderHistoryCard),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              offset: const Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Tên sân & Badge trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.facilityName,
                    style: BookingTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: BookingColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(booking.status),
              ],
            ),
            const SizedBox(height: 4),
            // Hàng 2: Loại sân
            Text(
              booking.courtName,
              style: BookingTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: BookingColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Hàng 3: Thời gian & Giá tiền
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(BookingIcons.clock, width: 14, height: 14),
                    const SizedBox(width: 6),
                    Text(
                      booking.dateTimeText,
                      style: BookingTypography.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: BookingColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      booking.priceText,
                      style: BookingTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: BookingColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SvgPicture.asset(
                      BookingIcons.chevronRight,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        BookingColors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget Badge trạng thái
  Widget _buildStatusBadge(BookingStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case BookingStatus.upcoming:
        bg = BookingColors.badgeUpcomingBg;
        text = BookingColors.badgeUpcomingText;
        label = 'Upcoming';
        break;
      case BookingStatus.completed:
        bg = BookingColors.badgeCompletedBg;
        text = BookingColors.badgeCompletedText;
        label = 'Completed';
        break;
      case BookingStatus.cancelled:
        bg = BookingColors.badgeCancelledBg;
        text = BookingColors.badgeCancelledText;
        label = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: BookingTypography.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  // 3. Bottom Navigation Bar (Cao 80px)
  Widget _buildBottomNav() {
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8E4), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, BookingIcons.navHome, 'Home', () {
            if (widget.onNavigateHome != null) widget.onNavigateHome!();
          }),
          _buildNavItem(1, BookingIcons.booking, 'Bookings', () {}),
          _buildNavItem(2, BookingIcons.search, 'Explore', () {}),
          _buildNavItem(3, BookingIcons.navMail, 'Messages', () {}),
          _buildNavItem(4, BookingIcons.navUser, 'Profile', () {
            if (widget.onNavigateProfile != null) widget.onNavigateProfile!();
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String icon,
    String label,
    VoidCallback onTap,
  ) {
    final isActive = _bottomNavIndex == index;
    final color = isActive
        ? BookingColors.primary
        : BookingColors.textSecondary;

    return InkWell(
      onTap: () {
        setState(() => _bottomNavIndex = index);
        onTap();
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            icon,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: BookingTypography.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
