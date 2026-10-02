import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../booking_theme.dart';

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  final String facilityName;
  final String courtName;
  final String address;
  final String dateText;
  final String timeRange;
  final String durationText;
  final String courtType;
  final String priceText;
  final String statusText;
  final VoidCallback? onCancelBooking;

  const BookingDetailScreen({
    super.key,
    this.bookingId = '#SM20260920001',
    this.facilityName = 'Sunrise Badminton Club',
    this.courtName = 'Sân 3 · Indoor Badminton Court',
    this.address = '123 Le Van Viet, D9, HCMC',
    this.dateText = 'Sun, 20 Sep 2026',
    this.timeRange = '19:00 – 19:30',
    this.durationText = '30 minutes',
    this.courtType = 'Indoor',
    this.priceText = '100,000 VND',
    this.statusText = 'Confirmed',
    this.onCancelBooking,
  });

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
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildStatusAndIdRow(),
              const SizedBox(height: 14),
              _buildCourtCard(),
              const SizedBox(height: 20),
              _buildBookingInformationSection(),
              const SizedBox(height: 16),
              _buildFacilityAndPolicyCard(context),
              const SizedBox(height: 24),
              _buildCancelButton(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Header: Back, Title & More
  Widget _buildHeader(BuildContext context) {
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
            child: SvgPicture.asset(BookingIcons.back, width: 18, height: 18),
          ),
        ),
        Text(
          'Booking Detail',
          style: BookingTypography.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BookingColors.textDark,
          ),
        ),
        InkWell(
          onTap: () {},
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
            child: SvgPicture.asset(BookingIcons.more, width: 18, height: 18),
          ),
        ),
      ],
    );
  }

  // 2. Status Badge & Booking ID Row
  Widget _buildStatusAndIdRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
              const SizedBox(width: 6),
              Text(
                'Upcoming',
                style: BookingTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: BookingColors.badgeUpcomingText,
                ),
              ),
            ],
          ),
        ),
        Text(
          bookingId,
          style: BookingTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BookingColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // 3. Court Card (345×92)
  Widget _buildCourtCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SvgPicture.asset(
              BookingIcons.courtThumbnail,
              width: 92,
              height: 62,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  facilityName,
                  style: BookingTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BookingColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  courtName,
                  style: BookingTypography.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: BookingColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SvgPicture.asset(
                      BookingIcons.location,
                      width: 12,
                      height: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: BookingTypography.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: BookingColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Booking Information Section (6 Rows)
  Widget _buildBookingInformationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Information',
          style: BookingTypography.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: BookingColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: BookingColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BookingColors.border),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                icon: BookingIcons.calendar,
                label: 'Date',
                value: dateText,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildInfoRow(
                icon: BookingIcons.clock,
                label: 'Time',
                value: timeRange,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildInfoRow(
                icon: BookingIcons.duration,
                label: 'Duration',
                value: durationText,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildInfoRow(
                icon: BookingIcons.indoor,
                label: 'Court Type',
                value: courtType,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildInfoRow(
                icon: BookingIcons.court,
                label: 'Price',
                value: priceText,
                valueColor: BookingColors.primary,
                isBoldValue: true,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildInfoRow(
                icon: BookingIcons.statusCheck,
                label: 'Status',
                value: statusText,
                valueColor: BookingColors.primary,
                isBoldValue: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required String icon,
    required String label,
    required String value,
    Color? valueColor,
    bool isBoldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SvgPicture.asset(icon, width: 20, height: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: BookingTypography.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: BookingColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: BookingTypography.inter(
              fontSize: 13,
              fontWeight: isBoldValue ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? BookingColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // 5. Combined Facility Information & Cancellation Policy Card
  Widget _buildFacilityAndPolicyCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BookingColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Facility Information...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset(BookingIcons.info, width: 18, height: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Facility Information',
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BookingColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  SvgPicture.asset(
                    BookingIcons.chevronRight,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      BookingColors.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: BookingColors.borderLight,
          ),
          InkWell(
            onTap: () {
              _showPolicyDialog(context);
            },
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SvgPicture.asset(BookingIcons.cancel, width: 18, height: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Cancellation Policy',
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BookingColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  SvgPicture.asset(
                    BookingIcons.chevronRight,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      BookingColors.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingColors.cardBg,
        title: Text(
          'Cancellation Policy',
          style: BookingTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Free cancellation is available up to 2 hours before the reservation start time. Cancellations made within 2 hours are non-refundable according to club policy.',
          style: BookingTypography.inter(
            fontSize: 13,
            color: BookingColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Understood',
              style: BookingTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BookingColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Cancel Booking Button (Viền đỏ #E2544B)
  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: BookingColors.background,
          side: const BorderSide(
            color: BookingColors.badgeCancelledText,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _confirmCancelDialog(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              BookingIcons.cancel,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                BookingColors.badgeCancelledText,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Cancel Booking',
              style: BookingTypography.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BookingColors.badgeCancelledText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BookingColors.cardBg,
        title: Text(
          'Cancel Reservation?',
          style: BookingTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel booking $bookingId? This slot will become available for others to book.',
          style: BookingTypography.inter(
            fontSize: 13,
            color: BookingColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep Booking',
              style: BookingTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BookingColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BookingColors.badgeCancelledText,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (onCancelBooking != null) {
                onCancelBooking!();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Booking has been cancelled')),
                );
                Navigator.maybePop(context);
              }
            },
            child: Text(
              'Yes, Cancel',
              style: BookingTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
