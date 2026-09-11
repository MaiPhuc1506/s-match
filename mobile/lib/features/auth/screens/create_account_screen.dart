import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/role_card.dart';
import 'court_owner_welcome_screen.dart';
import 'player_welcome_screen.dart';
import 'admin_welcome_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Vai trò mặc định được chọn theo Figma là "Player"
  String _selectedRole = 'Player';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header trên cùng (Nút Back + 3 Chấm tiến trình + Quả cầu chìm)
              _buildTopHeader(context),

              // 2. Nội dung Form (Padding 24px hai bên chuẩn 345px)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Tiêu đề Create Account (28pt/Bold)
                    Text('Create Account', style: AppTextStyles.titleBold),
                    const SizedBox(height: 8),

                    // Phụ đề
                    Text(
                      'Join S-Match and connect with badminton players',
                      style: AppTextStyles.bodySmallRegular,
                    ),
                    const SizedBox(height: 24),

                    // Ô nhập Full Name (icon Person)
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'Full Name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),

                    // Ô nhập Email
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'Email',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Ô nhập Password
                    CustomTextField(
                      controller: _passwordController,
                      hintText: 'Password',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),

                    // Nhãn "I am a"
                    Text(
                      'I am a',
                      style: AppTextStyles.titleBold.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hàng 3 thẻ vai trò (107 × 116, cách nhau 12px = 345px)
                    Row(
                      children: [
                        RoleCard(
                          title: 'Player',
                          icon: Icons.sports_tennis_rounded,
                          isSelected: _selectedRole == 'Player',
                          onTap: () {
                            setState(() {
                              _selectedRole = 'Player';
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        RoleCard(
                          title: 'Court Owner',
                          icon: Icons.stadium_outlined,
                          isSelected: _selectedRole == 'Court Owner',
                          onTap: () {
                            setState(() {
                              _selectedRole = 'Court Owner';
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        RoleCard(
                          title: 'Admin',
                          icon: Icons.shield_outlined,
                          isSelected: _selectedRole == 'Admin',
                          onTap: () {
                            setState(() {
                              _selectedRole = 'Admin';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Nút chính "Create Account"
                    PrimaryButton(
                      text: 'Create Account',
                      onPressed: () {
                        // Điều hướng chính xác theo 3 vai trò: Player, Court Owner, Admin
                        if (_selectedRole == 'Player') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlayerWelcomeScreen(),
                            ),
                          );
                        } else if (_selectedRole == 'Court Owner') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CourtOwnerWelcomeScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminWelcomeScreen(),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 18),

                    // Footer: "Already have an account? Log In"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: AppTextStyles.bodySmallRegular,
                        ),
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Header trên cùng: Back button, Progress Dots, Watermark Shuttle
  Widget _buildTopHeader(BuildContext context) {
    return SizedBox(
      height: 70,
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

          // 3 chấm tròn tiến trình ở giữa (Dot 1: 8x8 xanh, Dot 2&3: 7x7 xám)
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
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.border,
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

          // Icon quả cầu lông chìm (Watermark) ở góc trên bên phải (opacity 16%)
          Positioned(
            right: 20,
            child: SvgPicture.asset(
              'assets/images/shuttlecock.svg',
              width: 48,
              height: 48,
              colorFilter: ColorFilter.mode(
                AppColors.primary.withOpacity(0.16),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
