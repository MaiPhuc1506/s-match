import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Tiêu đề chính "Welcome Back" & Tên Brand "S-Match" (28/36, Bold - w700)
  static TextStyle get titleBold => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    height: 36 / 28, // line-height 36px
    fontWeight: FontWeight.w700,
    color: AppColors.primaryDark,
    letterSpacing: 0,
  );

  // Brand Name trên Header (Chữ trắng)
  static TextStyle get brandTitle => GoogleFonts.plusJakartaSans(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0,
  );

  // Tagline "Play More / Better More" trên Header (14/20, Regular - w400)
  static TextStyle get tagline => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
    letterSpacing: 0,
  );

  // Dòng phụ đề "Log in to continue..." & Prefix "Don't have an account?" (12/16, w400)
  static TextStyle get bodySmallRegular => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  // Chữ "OR" ở giữa hai đường kẻ (12/16, w400)
  static TextStyle get orText => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  // Link "Forgot Password?" & Action "Register" (12/16, Medium - w500)
  static TextStyle get linkMedium => GoogleFonts.plusJakartaSans(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.linkAction,
    letterSpacing: 0,
  );

  // Chữ trên nút chính "Log In" (14/20, SemiBold - w600)
  static TextStyle get buttonPrimary => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0,
  );

  // Chữ trên các nút Social "Continue with Google/SMS" (14/20, Medium - w500)
  static TextStyle get buttonSocial => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );

  // Placeholder của Input Field (14/20, w400)
  static TextStyle get inputPlaceholder => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  // Text người dùng gõ vào ô Input (14/20, w500)
  static TextStyle get inputText => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );
}
