import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback onPressed;

  const SocialButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Chiều cao 52px theo Figma
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          // Màu khi chạm vào nút (Pressed state #EEF7F3)
          overlayColor: AppColors.socialPressed,
          elevation: 0,
          // Viền xám #D6DCD8
          side: const BorderSide(color: AppColors.border, width: 1),
          // Bo góc 16px chuẩn Figma
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Google hoặc SMS
            SizedBox(width: 24, height: 24, child: Center(child: icon)),
            const SizedBox(width: 10),
            // Nhãn chữ nút
            Text(text, style: AppTextStyles.buttonSocial),
          ],
        ),
      ),
    );
  }
}
