import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Header trên cùng (Nút Back + 3 Chấm tiến trình với Dot 1 & Dot 2 sáng xanh)
              _buildTopHeader(context),

              const SizedBox(height: 38),

              // 2. Khối nội dung phục hồi mật khẩu (Recovery Content - căn giữa)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Vòng tròn minh họa 88x88 với icon Thư 44x44 chuẩn Figma
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: AppColors.illustrationCircle,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 44,
                          color: AppColors.iconPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tiêu đề: Forgot Password? (24/32/700)
                    Text(
                      'Forgot Password?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleBold.copyWith(
                        fontSize: 24,
                        height: 32 / 24,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dòng mô tả phụ đề (14/20/400)
                    Text(
                      'Enter your email address and we will send you a verification code to reset your password.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmallRegular.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ô nhập Email (345 × 52)
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    // Khoảng cách tới nút bấm Send Code
                    const SizedBox(height: 120),

                    // Nút chính "Send Code" (52px, Pill shape)
                    PrimaryButton(
                      text: 'Send Code',
                      onPressed: () {
                        // Xử lý gửi mã xác thực -> chuyển sang Flow / 04 Verify Code
                      },
                    ),
                    const SizedBox(height: 16),

                    // Chân trang: "Back to Log In"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Back to ', style: AppTextStyles.bodySmallRegular),
                        GestureDetector(
                          onTap: () {
                            // Quay lại màn Login
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Log In',
                            style: AppTextStyles.linkMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header trên cùng: Back button + 3 chấm tiến trình (Dot 1 & 2 Active, Dot 3 Inactive)
  Widget _buildTopHeader(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Nút Back ở bên trái
          Positioned(
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 24,
                color: AppColors.primaryDark,
              ),
            ),
          ),

          // 3 chấm tròn tiến trình (Dot 1 & 2: 8x8 màu xanh, Dot 3: 7x7 màu xám)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
