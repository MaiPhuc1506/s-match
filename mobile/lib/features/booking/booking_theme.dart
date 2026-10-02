import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu chuẩn Figma cho Sprint 4 (Node 301:635)
class BookingColors {
  BookingColors._();

  // Nền chung của cả 5 màn hình
  static const Color background = Color(0xFFF7F8F5);

  // Màu thương hiệu chính (Primary Green)
  static const Color primary = Color(0xFF05644F);
  static const Color primaryPressed = Color(0xFF054D3F);

  // Màu chữ chính và phụ
  static const Color textDark = Color(0xFF062F3A);
  static const Color textDarkM1 = Color(0xFF0D2630); // Dùng riêng ở Màn 01
  static const Color textSecondary = Color(0xFF68736F);
  static const Color textSecondaryM1 = Color(0xFF66706E); // Dùng riêng ở Màn 01

  // Card, viền & bề mặt
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFD7DFDB);
  static const Color borderLight = Color(0xFFEBF0ED);
  static const Color borderHistoryCard = Color(0xFFEBF0ED);
  static const Color borderStat = Color(0xFFDBE3DE);
  static const Color termsBoxBg = Color(0xFFEEF6F2);

  // Badges trạng thái
  static const Color badgeUpcomingBg = Color(0xFFDDF1E9);
  static const Color badgeUpcomingText = Color(0xFF05644F);

  static const Color badgeCompletedBg = Color(0xFFDDEFFF);
  static const Color badgeCompletedText = Color(0xFF2674A8);

  static const Color badgeCancelledBg = Color(0xFFFFE2E0);
  static const Color badgeCancelledText = Color(0xFFE2544B);

  // Màu ma trận trạng thái slot trên lịch (Schedule Grid)
  static const Color slotAvailable = Color(0xFF128C6B);
  static const Color slotBooked = Color(0xFFFA635E);
  static const Color slotLocked = Color(0xFFB8BFBD);
  static const Color slotEvent = Color(0xFFBD5CD1);
  static const Color slotSelectedBorder = Color(0xFFA9DDCC);
}

/// Đường dẫn toàn bộ 28 icons SVG Figma đã xuất cho Sprint 4
class BookingIcons {
  BookingIcons._();

  static const String back = 'assets/icons/sprint4_back.svg';
  static const String booking = 'assets/icons/sprint4_booking.svg';
  static const String calendar = 'assets/icons/sprint4_calendar.svg';
  static const String cancel = 'assets/icons/sprint4_cancel.svg';
  static const String chevronRight = 'assets/icons/sprint4_chevron_right.svg';
  static const String clock = 'assets/icons/sprint4_clock.svg';
  static const String confetti = 'assets/icons/sprint4_confetti.svg';
  static const String continueArrow = 'assets/icons/sprint4_continue_arrow.svg';
  static const String copy = 'assets/icons/sprint4_copy.svg';
  static const String court = 'assets/icons/sprint4_court.svg';
  static const String courtPattern = 'assets/icons/sprint4_court_pattern.svg';
  static const String courtThumbnail =
      'assets/icons/sprint4_court_thumbnail.svg';
  static const String duration = 'assets/icons/sprint4_duration.svg';
  static const String facilityBack = 'assets/icons/sprint4_facility_back.svg';
  static const String facilityLocation =
      'assets/icons/sprint4_facility_location.svg';
  static const String facilityMore = 'assets/icons/sprint4_facility_more.svg';
  static const String favoriteOutline =
      'assets/icons/sprint4_favorite_outline.svg';
  static const String indoor = 'assets/icons/sprint4_indoor.svg';
  static const String info = 'assets/icons/sprint4_info.svg';
  static const String location = 'assets/icons/sprint4_location.svg';
  static const String more = 'assets/icons/sprint4_more.svg';
  static const String navHome = 'assets/icons/sprint4_nav_home.svg';
  static const String navMail = 'assets/icons/sprint4_nav_mail.svg';
  static const String navUser = 'assets/icons/sprint4_nav_user.svg';
  static const String search = 'assets/icons/sprint4_search.svg';
  static const String statCourt = 'assets/icons/sprint4_stat_court.svg';
  static const String statusCheck = 'assets/icons/sprint4_status_check.svg';
  static const String successBadge = 'assets/icons/sprint4_success_badge.svg';
}

/// Typography helper theo đúng phân bổ font của Figma:
/// - Màn 01 dùng GoogleFonts.plusJakartaSans
/// - Màn 02-05 dùng GoogleFonts.inter
class BookingTypography {
  BookingTypography._();

  static TextStyle jakarta({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = BookingColors.textDarkM1,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = BookingColors.textDark,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}
