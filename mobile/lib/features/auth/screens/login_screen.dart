import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/auth_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/social_button.dart';
import 'admin_welcome_screen.dart';
import 'court_owner_welcome_screen.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import 'player_welcome_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập mật khẩu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.instance.login(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Đăng nhập thất bại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Đăng nhập thành công -> Điều hướng theo vai trò
    final role = result.user?['role']?.toString().toUpperCase() ?? 'PLAYER';
    Widget targetScreen;
    if (role == 'COURT_OWNER' || role == 'COURT OWNER') {
      targetScreen = const CourtOwnerWelcomeScreen();
    } else if (role == 'ADMIN') {
      targetScreen = const AdminWelcomeScreen();
    } else {
      targetScreen = const PlayerWelcomeScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            // 1. Header ảnh cây vợt + vòm cong
            const AuthHeader(),

            // 2. Nội dung Form đăng nhập (Padding 24px hai bên)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tiêu đề Welcome Back
                  Text('Welcome Back', style: AppTextStyles.titleBold),
                  const SizedBox(height: 8),

                  // Dòng phụ đề
                  Text(
                    'Log in to continue your badminton journey',
                    style: AppTextStyles.bodySmallRegular,
                  ),
                  const SizedBox(height: 24),

                  // Ô nhập Email
                  CustomTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),

                  // Ô nhập Password
                  CustomTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  const SizedBox(height: 10),

                  // Quên mật khẩu
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        // Chuyển trang sang màn Forgot Password
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: AppTextStyles.linkMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Nút chính "Log In"
                  PrimaryButton(
                    text: 'Log In',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 16),

                  // Đường kẻ phân cách "OR"
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: AppColors.divider, thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: AppTextStyles.orText),
                      ),
                      const Expanded(
                        child: Divider(color: AppColors.divider, thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nút "Continue with Google"
                  SocialButton(
                    text: 'Continue with Google',
                    icon: Image.network(
                      'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                      width: 22,
                      height: 22,
                    ),
                    onPressed: () {
                      // Xử lý đăng nhập Google
                    },
                  ),
                  const SizedBox(height: 12),

                  // Nút "Continue with SMS"
                  SocialButton(
                    text: 'Continue with SMS',
                    icon: const Icon(
                      Icons.phone_outlined,
                      color: AppColors.iconPrimary,
                      size: 22,
                    ),
                    onPressed: () {
                      // Xử lý đăng nhập SMS
                    },
                  ),
                  const SizedBox(height: 20),

                  // Dòng đăng ký tài khoản (Footer)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: AppTextStyles.bodySmallRegular,
                      ),
                      GestureDetector(
                        onTap: () {
                          // Chuyển trang sang màn Create Account
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateAccountScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Register',
                          style: AppTextStyles.linkMedium,
                        ),
                      ),
                    ],
                  ),

                  // Khoảng đệm dưới cùng
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
