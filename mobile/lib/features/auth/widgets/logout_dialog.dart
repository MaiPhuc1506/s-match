import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/login_screen.dart';
import '../services/auth_service.dart';

/// Hiển thị Dialog xác nhận đăng xuất chuẩn UX và xử lý thu hồi token an toàn
Future<void> showLogoutConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE53935),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1C),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            height: 1.5,
            color: const Color(0xFF6B6B6B),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Hủy',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B6B6B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935), // Màu đỏ cảnh báo
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );

  // Người dùng bấm "Hủy" hoặc bấm ra ngoài
  if (confirmed != true) return;

  if (!context.mounted) return;

  // 1. Hiển thị vòng xoay Loading (chặn touch hoàn toàn để tránh bấm nhiều lần)
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF05644F)),
      ),
    ),
  );

  // 2. Thu hồi session từ backend và dọn sạch token
  await AuthService.instance.logout();

  if (!context.mounted) return;

  // 3. Đóng popup loading
  Navigator.of(context, rootNavigator: true).pop();

  // 4. Quay về màn hình LoginScreen và XÓA TOÀN BỘ navigation stack
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}
