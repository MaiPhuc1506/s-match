import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../data/dev_saved_accounts_repository.dart';

/// Các hộp thoại và BottomSheet tiện ích để chọn, đăng nhập, thêm, sửa tài khoản test.
class DevAccountSelector {
  DevAccountSelector._();

  /// Hộp thoại đăng nhập nhanh cho một tài khoản
  static Future<void> showQuickLoginDialog({
    required BuildContext context,
    required DevAccount account,
    required Future<bool> Function(String email, String password) onLogin,
    required void Function(String role) onSuccess,
  }) async {
    final passwordController = TextEditingController(text: 'Password123!');
    bool obscurePassword = true;
    bool isLoading = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Đăng nhập nhanh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu tài khoản',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final pass = passwordController.text.trim();
                          if (pass.isEmpty) {
                            setState(() => errorMessage = 'Vui lòng nhập mật khẩu');
                            return;
                          }
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          final success = await onLogin(account.email, pass);
                          if (dialogCtx.mounted) {
                            if (success) {
                              // Đóng dialog TRƯỚC TIÊN
                              Navigator.pop(dialogCtx);
                              // Kích hoạt điều hướng sau khi dialog đã đóng hoàn toàn
                              onSuccess(account.role);
                            } else {
                              setState(() {
                                isLoading = false;
                                errorMessage =
                                    'Đăng nhập không thành công. Kiểm tra lại thông tin hoặc kết nối máy chủ.';
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Đăng nhập'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hộp thoại thêm hoặc sửa thông tin tài khoản test
  static Future<void> showAddEditAccountDialog({
    required BuildContext context,
    DevAccount? initialAccount,
    required Future<void> Function(DevAccount account) onSave,
  }) async {
    final isEditing = initialAccount != null;
    final labelController =
        TextEditingController(text: initialAccount?.label ?? '');
    final emailController =
        TextEditingController(text: initialAccount?.email ?? '');
    final noteController =
        TextEditingController(text: initialAccount?.note ?? '');
    String selectedRole = initialAccount?.role ?? 'PLAYER';

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isEditing ? 'Sửa tài khoản test' : 'Thêm tài khoản test mới',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: InputDecoration(
                        labelText: 'Tên gợi nhớ (Label)',
                        hintText: 'VD: Player 03 (Vip)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'VD: player3@smatch.dev',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Vai trò (Role)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'PLAYER',
                          child: Text('Player (Người chơi)'),
                        ),
                        DropdownMenuItem(
                          value: 'COURT_OWNER',
                          child: Text('Court Owner (Chủ sân)'),
                        ),
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Text('Admin (Quản trị viên)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: 'Ghi chú (Tùy chọn)',
                        hintText: 'VD: Dùng để test tính năng tạo match...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final label = labelController.text.trim();
                    final email = emailController.text.trim();
                    if (label.isEmpty || email.isEmpty) return;

                    final updated = DevAccount(
                      id: initialAccount?.id ??
                          'acc_${DateTime.now().millisecondsSinceEpoch}',
                      label: label,
                      email: email,
                      role: selectedRole,
                      note: noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : null,
                      lastUsedAt: initialAccount?.lastUsedAt,
                    );

                    await onSave(updated);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hộp thoại đổi tên nhanh
  static Future<void> showRenameDialog({
    required BuildContext context,
    required DevAccount account,
    required Future<void> Function(String newLabel) onRename,
  }) async {
    final controller = TextEditingController(text: account.label);
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Đổi tên hiển thị'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Tên hiển thị mới',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  await onRename(text);
                }
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  /// Hộp thoại xác nhận xóa tài khoản test
  static Future<void> showConfirmDeleteDialog({
    required BuildContext context,
    required DevAccount account,
    required Future<void> Function() onDelete,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Xóa tài khoản test'),
          content: Text('Bạn có chắc chắn muốn xóa "${account.label}" khỏi danh sách lưu?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Hủy'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                await onDelete();
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }
}

