import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool showArrow;
  final double height;
  final Widget? arrow;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.showArrow = true,
    this.height = 52,
    this.arrow,
  });

  @override
  Widget build(BuildContext context) {
    // Chiều cao chuẩn 52px theo Figma
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, // Màu xanh #05644F
          foregroundColor: AppColors.white,
          elevation: 0, // Phẳng, không đổ bóng theo Figma
          // Bo góc 26px (dạng viên thuốc - Pill shape)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.buttonPrimary,
                    ),
                  ),
                  if (showArrow) const SizedBox(width: 8),
                  // Mũi tên trắng chỉ sang phải
                  if (showArrow)
                    arrow ??
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: AppColors.white,
                        ),
                ],
              ),
      ),
    );
  }
}
