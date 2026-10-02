import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../booking_theme.dart';

class BookingSummaryScreen extends StatelessWidget {
  final String facilityName;
  final String courtName;
  final String dateText;
  final String timeRange;
  final String durationText;
  final String courtType;
  final String priceText;
  final VoidCallback? onConfirm;

  const BookingSummaryScreen({
    super.key,
    this.facilityName = 'Sunrise Badminton Club',
    this.courtName = 'Sân 3 · Indoor Badminton Court',
    this.dateText = 'Sun, 20 Sep 2026',
    this.timeRange = '19:00 – 19:30',
    this.durationText = '30 minutes',
    this.courtType = 'Indoor',
    this.priceText = '100,000 VND',
    this.onConfirm,
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
              _buildCourtCard(),
              const SizedBox(height: 20),
              _buildBookingDetails(),
              const SizedBox(height: 20),
              _buildPriceDetails(),
              const SizedBox(height: 16),
              _buildTermsNotice(),
              const SizedBox(height: 24),
              _buildConfirmButton(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Header: Back & Title
  Widget _buildHeader(BuildContext context) {
    return Row(
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
        const SizedBox(width: 14),
        Text(
          'Booking Summary',
          style: BookingTypography.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BookingColors.textDark,
          ),
        ),
      ],
    );
  }

  // 2. Court Summary Card
  Widget _buildCourtCard() {
    return Container(
      width: double.infinity,
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              width: 86,
              height: 58,
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
                const SizedBox(height: 4),
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
                Text(
                  priceText,
                  style: BookingTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BookingColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Booking Details Section (4 Rows)
  Widget _buildBookingDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking Details',
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
              _buildDetailRow(
                icon: BookingIcons.calendar,
                label: 'Date',
                value: dateText,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildDetailRow(
                icon: BookingIcons.clock,
                label: 'Time',
                value: timeRange,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildDetailRow(
                icon: BookingIcons.duration,
                label: 'Duration',
                value: durationText,
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BookingColors.borderLight,
              ),
              _buildDetailRow(
                icon: BookingIcons.indoor,
                label: 'Court Type',
                value: courtType,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required String icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              fontWeight: FontWeight.w600,
              color: BookingColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Price Details Section
  Widget _buildPriceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Details',
          style: BookingTypography.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: BookingColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: BookingColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BookingColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Court Fee',
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: BookingColors.textSecondary,
                    ),
                  ),
                  Text(
                    priceText,
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BookingColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Service Fee',
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: BookingColors.textSecondary,
                    ),
                  ),
                  Text(
                    '0 VND',
                    style: BookingTypography.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: BookingColors.primary,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: BookingColors.borderLight,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: BookingTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: BookingColors.textDark,
                    ),
                  ),
                  Text(
                    priceText,
                    style: BookingTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: BookingColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. Terms Notice Box (Nền #EEF6F2)
  Widget _buildTermsNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BookingColors.termsBoxBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            BookingIcons.info,
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              BookingColors.primary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'By tapping Confirm Booking, you agree to the facility rules and cancellation policy. Free cancellation up to 2 hours before play time.',
              style: BookingTypography.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: BookingColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Confirm Booking Button
  Widget _buildConfirmButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: BookingColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          if (onConfirm != null) {
            onConfirm!();
          }
        },
        child: Text(
          'Confirm Booking',
          style: BookingTypography.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
