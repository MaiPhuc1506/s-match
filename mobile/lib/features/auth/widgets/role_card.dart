import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final double height;
  final Widget? iconWidget;

  const RoleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.width = 107,
    this.height = 116,
    this.iconWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Kích thước chuẩn Figma: 107 × 116, bo góc 14px
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 200,
        ), // Smart Animate 200ms theo Figma
        width: width,
        height: height,
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        decoration: BoxDecoration(
          // Khi chọn: nền #DDEFE7, chưa chọn: nền trắng
          color: isSelected ? AppColors.roleSelectedCard : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // Khi chọn: viền 1.5px xanh #087A61, chưa chọn: viền 1px xám #D6DCD8
            color: isSelected ? AppColors.inputFocusedBorder : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon vai trò 32x32
            iconWidget ??
                Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
            const SizedBox(height: 10),
            // Tên vai trò (12/16, w500)
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.linkMedium.copyWith(
                color: AppColors.iconPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
