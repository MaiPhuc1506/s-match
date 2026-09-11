import 'package:flutter/material.dart';

class AppColors {
  // Ngăn không cho khởi tạo đối tượng vì đây là class chứa hằng số tĩnh
  AppColors._();

  // Background chính của toàn bộ màn hình (#F7F8F5)
  static const Color background = Color(0xFFF7F8F5);

  // Màu thương hiệu chính (Primary Brand) - Dùng cho nút Log In (#05644F)
  static const Color primary = Color(0xFF05644F);

  // Màu xanh đậm - Dùng cho Tiêu đề "Welcome Back" và Logo (#054D40)
  static const Color primaryDark = Color(0xFF054D40);

  // Màu icon trong input field và icon SMS (#054D3F)
  static const Color iconPrimary = Color(0xFF054D3F);

  // Màu viền khi người dùng bấm vào ô nhập liệu (Focused State) (#087A61)
  static const Color inputFocusedBorder = Color(0xFF087A61);

  // Màu nền nút Social khi nhấn vào (Pressed State) (#EEF7F3)
  static const Color socialPressed = Color(0xFFEEF7F3);

  // Màu viền xám của ô nhập liệu và nút Social (#D6DCD8)
  static const Color border = Color(0xFFD6DCD8);

  // Màu đường kẻ phân cách Divider "OR" (#D6DBD9)
  static const Color divider = Color(0xFFD6DBD9);

  // Màu chữ chính trên nút Social (#1C1C1C)
  static const Color textPrimary = Color(0xFF1C1C1C);

  // Màu chữ phụ / mô tả / placeholder (#6B6B6B)
  static const Color textSecondary = Color(0xFF6B6B6B);

  // Màu nhấn cho link "Forgot Password?" và "Register" (#914A45)
  static const Color linkAction = Color(0xFF914A45);
  // Màu nền vòng tròn minh họa #DEF0E8 trong màn Forgot Password
  static const Color illustrationCircle = Color(0xFFDEF0E8);
  // Màu trắng cơ bản
  static const Color white = Color(0xFFFFFFFF);
  // Màu nền thẻ Role khi được chọn (#DDEFE7) chuẩn Figma
  // Màu nền banner minh họa sân cầu lông #EDF7F2 (màn Player Welcome)
  static const Color bannerMintBg = Color(0xFFEDF7F2);
  static const Color roleSelectedCard = Color(0xFFDDEFE7);
  // Màu nền và viền banner màn Admin Welcome chuẩn Figma (#FAF0F0 & #E6D1CF)
  static const Color adminBannerBg = Color(0xFFFAF0F0);
  static const Color adminBannerBorder = Color(0xFFE6D1CF);
  // Lớp phủ Gradient (Scrim) cho Header ảnh vợt/cầu lông
  static const List<Color> headerScrimGradient = [
    Color(0x29054D3D), // rgba(0.02, 0.30, 0.24, 0.16) - Alpha 16% ở trên
    Color(0xA8031F1A), // rgba(0.01, 0.12, 0.10, 0.66) - Alpha 66% ở dưới
  ];
}
