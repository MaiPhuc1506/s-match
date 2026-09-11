import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class AdminWelcomeScreen extends StatelessWidget {
  const AdminWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 1. Header xanh thương hiệu #05644F (Chiều cao 104px theo Figma)
          _buildBrandHeader(),

          // 2. Nội dung chính (Cuộn được, Padding 24px hai bên)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner minh họa Admin với icon authentication_2.svg (345 × 116, bo góc 20px)
                  _buildAdminBanner(),
                  const SizedBox(height: 16),

                  // Tiêu đề: Welcome, Admin! (28/36/700)
                  Text('Welcome, Admin!', style: AppTextStyles.titleBold),
                  const SizedBox(height: 6),

                  // Dòng phụ đề (14/20/400)
                  Text(
                    'Your system administration workspace is ready.',
                    style: AppTextStyles.bodySmallRegular.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thẻ xác nhận vai trò Admin Confirmation Card (345 × 180, bo góc 20px)
                  _buildConfirmationCard(),
                  const SizedBox(height: 24),

                  // Nút chính "Continue"
                  PrimaryButton(
                    text: 'Continue',
                    onPressed: () {
                      // Xử lý vào Admin Dashboard sau này
                    },
                  ),
                  const SizedBox(height: 12),

                  // Nút phụ "Log Out" (Pill shape 52px, nền trắng, chữ xanh #054D3F)
                  _buildLogOutButton(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header trên cùng màu xanh đậm #05644F với Logo S-Match
  Widget _buildBrandHeader() {
    return Container(
      height: 104,
      width: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon quả cầu trắng
              SvgPicture.asset(
                'assets/images/shuttlecock.svg',
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              // Tên thương hiệu S-Match
              Text(
                'S-Match',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner minh họa Admin (nền #FAF0F0, viền #E6D1CF, 3 line #914A45 và icon khiên 56x56)
  Widget _buildAdminBanner() {
    return Container(
      height: 116,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.adminBannerBg, // #FAF0F0
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.adminBannerBorder, width: 1),
      ),
      child: Stack(
        children: [
          // 3 đường kẻ ngang mờ bắt đầu tại x=34, chiều dài 180 / 156 / 132
          Positioned.fill(child: CustomPaint(painter: _AdminLinesPainter())),
          // Icon chiếc khiên bảo mật 56x56 góc phải từ authentication_2.svg
          Positioned(
            right: 24,
            top: 30,
            child: SvgPicture.asset(
              'assets/icons/authentication_2.svg',
              width: 56,
              height: 56,
              colorFilter: const ColorFilter.mode(
                AppColors.iconPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ xác nhận vai trò Admin (345 × 180, nền #EEF7F3, bo góc 20px)
  Widget _buildConfirmationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.socialPressed, // #EEF7F3
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon khiên bảo mật 40x40
          SvgPicture.asset(
            'assets/icons/authentication_2.svg',
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(
              AppColors.iconPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 14),

          // Overline nhãn ADMIN (10pt, tracking 12%, #054D3F)
          Text(
            'ADMIN',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.iconPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Thông điệp xác nhận
          Text(
            'You are signed in as an Administrator.',
            style: AppTextStyles.bodySmallRegular.copyWith(
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút Log Out (Pill-shape 52px, nền trắng, chữ xanh #054D3F)
  Widget _buildLogOutButton(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // Quay về màn hình Login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          'Log Out',
          style: AppTextStyles.buttonSocial.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.iconPrimary,
          ),
        ),
      ),
    );
  }
}

/// Vẽ 3 đường kẻ ngang mờ đặc trưng của banner Admin (chiều dài 180 / 156 / 132, mờ 18%)
class _AdminLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.linkAction
          .withOpacity(0.18) // #914A45 mờ 18%
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const startX = 34.0;
    // Dòng 1: dài 180
    canvas.drawLine(
      const Offset(startX, 36),
      const Offset(startX + 180, 36),
      paint,
    );
    // Dòng 2: dài 156
    canvas.drawLine(
      const Offset(startX, 58),
      const Offset(startX + 156, 58),
      paint,
    );
    // Dòng 3: dài 132
    canvas.drawLine(
      const Offset(startX, 80),
      const Offset(startX + 132, 80),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
