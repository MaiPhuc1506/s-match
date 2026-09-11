import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // Chiều cao chuẩn Header theo Figma: 340px
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(
        children: [
          // Lớp 1: Ảnh nền cây vợt cầu lông thật từ Figma
          Positioned.fill(
            child: Image.asset(
              'assets/images/header_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Lớp 2: Lớp phủ Scrim Gradient (xanh đậm từ trên xuống)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.headerScrimGradient,
                ),
              ),
            ),
          ),

          // Lớp 3: Nội dung thương hiệu (Icon Shuttlecock SVG + S-Match + Tagline)
          Positioned(
            left: 32,
            top: 52, // Khớp Figma (32, 52)
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon quả cầu lông SVG chính gốc từ Figma
                SvgPicture.asset(
                  'assets/images/shuttlecock.svg',
                  width: 36,
                  height: 36,
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 8),

                // Tên thương hiệu "S-Match"
                Text('S-Match', style: AppTextStyles.brandTitle),
                const SizedBox(height: 12),

                // Khẩu hiệu "Play More\nBetter More"
                Text('Play More\nBetter More', style: AppTextStyles.tagline),
              ],
            ),
          ),

          // Lớp 4: Vòm cong chuyển tiếp (Curved Boundary) uốn lượn hình cánh cung
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 95,
            child: CustomPaint(painter: _CurvedBoundaryPainter()),
          ),
        ],
      ),
    );
  }
}

/// Painter vẽ vòm cong lượn lên hình cánh cung chuẩn Figma
class _CurvedBoundaryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors
          .background // Màu nền #F7F8F5
      ..style = PaintingStyle.fill;

    final path = Path();
    // Bắt đầu từ mép trái
    path.moveTo(0, 38);

    // Đường cong hình vòm nhô lên phía trên
    path.cubicTo(
      size.width * 0.25,
      -8, // Điểm uốn trái nhô lên
      size.width * 0.55,
      -8, // Điểm uốn giữa nhô lên
      size.width,
      58, // Điểm kết thúc mép phải
    );

    // Kéo xuống hết đáy để phủ màu nền
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
