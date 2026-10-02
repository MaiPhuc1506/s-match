import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../booking_theme.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String bookingId;
  final String facilityName;
  final String courtName;
  final String address;
  final String dateTimeText;
  final String totalPrice;
  final VoidCallback? onViewBookings;
  final VoidCallback? onBackHome;

  const BookingSuccessScreen({
    super.key,
    this.bookingId = '#SM20260920001',
    this.facilityName = 'Sunrise Badminton Club',
    this.courtName = 'Sân 3 · Indoor Badminton Court',
    this.address = '123 Le Van Viet, D9, HCMC',
    this.dateTimeText = 'Sun, 20 Sep 2026 · 19:00 – 19:30',
    this.totalPrice = '100,000 VND',
    this.onViewBookings,
    this.onBackHome,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTopCloseButton(context),
              const SizedBox(height: 12),
              _buildSuccessIllustration(),
              const SizedBox(height: 16),
              _buildTitles(),
              const SizedBox(height: 24),
              _buildConfirmationCard(),
              const SizedBox(height: 16),
              _buildBookingIdCard(context),
              const SizedBox(height: 32),
              _buildActionButtons(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Nút Close '×' góc trên phải
  Widget _buildTopCloseButton(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: InkWell(
        onTap: () {
          if (widget.onViewBookings != null) {
            widget.onViewBookings!();
          } else {
            Navigator.maybePop(context);
          }
        },
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
          child: const Icon(
            Icons.close,
            size: 20,
            color: BookingColors.textDark,
          ),
        ),
      ),
    );
  }

  // 2. Pháo giấy chuyển động quanh dấu tick khi màn xác nhận xuất hiện.
  Widget _buildSuccessIllustration() {
    return SizedBox(
      width: 180,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(180, 110),
            painter: _BookingConfettiPainter(_celebrationController),
          ),
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _celebrationController,
              curve: const Interval(0, 0.35, curve: Curves.easeOutBack),
            ),
            child: SvgPicture.asset(
              BookingIcons.successBadge,
              width: 58,
              height: 58,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Tiêu đề Booking Confirmed!
  Widget _buildTitles() {
    return Column(
      children: [
        Text(
          'Booking Confirmed!',
          style: BookingTypography.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BookingColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your court has been successfully reserved',
          style: BookingTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: BookingColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // 4. Confirmation Card (345×188, radius 14)
  Widget _buildConfirmationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BookingColors.border),
      ),
      child: Column(
        children: [
          Row(
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
                  children: [
                    Text(
                      widget.facilityName,
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
                      widget.courtName,
                      style: BookingTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: BookingColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: BookingColors.borderLight,
            ),
          ),
          _buildInfoRow(icon: BookingIcons.location, text: widget.address),
          const SizedBox(height: 8),
          _buildInfoRow(icon: BookingIcons.calendar, text: widget.dateTimeText),
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
                'Total Paid',
                style: BookingTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: BookingColors.textSecondary,
                ),
              ),
              Text(
                widget.totalPrice,
                style: BookingTypography.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BookingColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({required String icon, required String text}) {
    return Row(
      children: [
        SvgPicture.asset(icon, width: 16, height: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: BookingTypography.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: BookingColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // 5. Booking ID Card với nút copy
  Widget _buildBookingIdCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: BookingColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BookingColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BOOKING ID',
                style: BookingTypography.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: BookingColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.bookingId,
                style: BookingTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: BookingColors.textDark,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.bookingId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied ${widget.bookingId} to clipboard!'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BookingColors.termsBoxBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                BookingIcons.copy,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(
                  BookingColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Action Buttons: View My Bookings & Back to Home
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
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
              if (widget.onViewBookings != null) {
                widget.onViewBookings!();
              }
            },
            child: Text(
              'View My Bookings',
              style: BookingTypography.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: BookingColors.background,
              side: const BorderSide(color: BookingColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              if (widget.onBackHome != null) {
                widget.onBackHome!();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(
              'Back to Home',
              style: BookingTypography.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: BookingColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingConfettiPainter extends CustomPainter {
  _BookingConfettiPainter(Animation<double> animation)
    : _animation = animation,
      super(repaint: animation);

  final Animation<double> _animation;

  static const _colors = [
    BookingColors.primary,
    Color(0xFFA9DDCC),
    Color(0xFF924A45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < 28; index++) {
      final delay = index.isEven ? 0.0 : 0.12;
      final progress = ((_animation.value - delay) / (1 - delay)).clamp(
        0.0,
        1.0,
      );
      if (progress == 0 || progress == 1) continue;

      final angle = 2 * math.pi * index / 28 + 0.15;
      final distance = 31 + (index % 5) * 9.0;
      final travel = Curves.easeOutCubic.transform(progress);
      final position =
          center +
          Offset(
            math.cos(angle) * distance * travel,
            math.sin(angle) * distance * 0.65 * travel +
                22 * progress * progress,
          );
      final opacity = (1 - progress).clamp(0.0, 1.0);
      paint.color = _colors[index % _colors.length].withValues(alpha: opacity);

      final direction = Offset(
        math.cos(angle + progress * 3) * 3,
        math.sin(angle + progress * 3) * 3,
      );
      canvas.drawLine(position - direction, position + direction, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BookingConfettiPainter oldDelegate) =>
      oldDelegate._animation != _animation;
}
