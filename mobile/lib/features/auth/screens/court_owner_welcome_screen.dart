import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class CourtOwnerWelcomeScreen extends StatelessWidget {
  const CourtOwnerWelcomeScreen({super.key});

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
                  // Banner minh họa sân cầu lông với icon court_2.svg (345 × 116, bo góc 20px)
                  _buildIllustrationBanner(),
                  const SizedBox(height: 16),

                  // Tiêu đề: Welcome, Court Owner! (28/36/700)
                  Text('Welcome, Court Owner!', style: AppTextStyles.titleBold),
                  const SizedBox(height: 6),

                  // Dòng phụ đề (14/20/400)
                  Text(
                    'Your court management workspace is ready.',
                    style: AppTextStyles.bodySmallRegular.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Thẻ xác nhận vai trò Confirmation Card (345 × 180, bo góc 20px)
                  _buildConfirmationCard(),
                  const SizedBox(height: 24),

                  // Nút chính "Continue"
                  PrimaryButton(
                    text: 'Continue',
                    onPressed: () {
                      // Xử lý vào không gian quản lý sân sau này
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

  /// Banner minh họa sân cầu lông với 4 vạch kẻ mờ và icon Court 56x56
  Widget _buildIllustrationBanner() {
    return Container(
      height: 116,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bannerMintBg, // #EDF7F2
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Stack(
        children: [
          // 4 đường kẻ sân mờ (opacity 18%)
          Positioned.fill(child: CustomPaint(painter: _CourtLinesPainter())),
          // Icon Sân cầu lông 56x56 góc phải từ asset court_2.svg
          Positioned(
            right: 24,
            top: 30,
            child: SvgPicture.asset(
              'assets/icons/court_2.svg',
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

  /// Thẻ xác nhận vai trò Court Owner (345 × 180, nền #EEF7F3, bo góc 20px)
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
          // Icon sân cầu lông 40x40
          SvgPicture.asset(
            'assets/icons/court_2.svg',
            width: 40,
            height: 40,
            colorFilter: const ColorFilter.mode(
              AppColors.iconPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 14),

          // Overline nhãn COURT OWNER (10pt, tracking 12%, #054D3F)
          Text(
            'COURT OWNER',
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
            'You are signed in as a Court Owner.',
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
          // Quay về màn hình Login và xóa hết stack cũ
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
            color: AppColors.iconPrimary, // Màu xanh #054D3F theo Figma
          ),
        ),
      ),
    );
  }
}

/// Vẽ 4 đường vạch kẻ sân cầu lông tượng trưng (cao 2px, mờ 18%)
class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 4 vạch tượng trưng theo Figma
    canvas.drawLine(
      Offset(size.width * 0.12, 0),
      Offset(size.width * 0.12, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.58, 0),
      Offset(size.width * 0.58, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width * 0.65, size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
