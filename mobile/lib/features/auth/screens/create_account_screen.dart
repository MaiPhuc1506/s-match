import '../../../core/theme/app_motion_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/role_card.dart';
import 'court_owner_welcome_screen.dart';
import 'player_welcome_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

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
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập họ và tên'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập email'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu phải từ 6 ký tự trở lên'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedRole == 'Court Owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Court Owner registration is not supported by the current API. Please use an existing Owner account.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.instance.register(
      email: email,
      password: password,
      fullName: name,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Đăng ký thất bại'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Registration only creates a user; the endpoint does not issue a session.
    // Clear any previous account before authenticating the newly created user.
    await AuthService.instance.logout();
    final login = await AuthService.instance.login(
      email: email,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    final registeredId = (result.user?['id'] as num?)?.toInt();
    final loggedInId = (login.user?['id'] as num?)?.toInt();
    if (!login.isSuccess ||
        registeredId == null ||
        loggedInId != registeredId ||
        login.accessToken == null) {
      await AuthService.instance.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created. Please sign in to continue.'),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      return;
    }
    final role = login.user?['role']?.toString().toUpperCase();
    final Widget targetScreen = role == 'COURT_OWNER' || role == 'COURT OWNER'
        ? const CourtOwnerWelcomeScreen()
        : const PlayerWelcomeScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => targetScreen),
      (_) => false,
    );
  }

  Widget _asset(String name, double size) => SvgPicture.asset(
    'assets/icons/register_$name.svg',
    width: size,
    height: size,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final headerTop = media.padding.top > 44 ? media.padding.top : 44.0;
    final contentTop = headerTop + 56 > 120 ? headerTop + 56 : 120.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: .9,
                child: SvgPicture.asset(
                  'assets/icons/register_corner.svg',
                  width: 128,
                  height: 96,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              24,
              contentTop,
              24,
              media.padding.bottom + 24,
            ),
            child: AppStaggeredColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Account', style: AppTextStyles.titleBold),
                const SizedBox(height: 12),
                Text(
                  'Join S-Match and be part of our\nbadminton community',
                  style: AppTextStyles.inputPlaceholder,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  height: 56,
                  leading: _asset('user', 16),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  prefixIcon: Icons.mail_outline,
                  height: 56,
                  leading: _asset('mail', 16),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  height: 56,
                  leading: _asset('lock', 16),
                  visibilityIcon: _asset('eye', 16),
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                Text(
                  'I am a',
                  style: AppTextStyles.inputText.copyWith(
                    color: AppColors.iconPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Row(
                      children: [
                        for (final role in ['Player', 'Court Owner']) ...[
                          if (role == 'Court Owner') const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              selected: _selectedRole == role,
                              button: true,
                              child: RoleCard(
                                title: role,
                                icon: Icons.person_outline,
                                iconWidget: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Center(
                                    child: _asset(
                                      role == 'Player' ? 'racket' : 'court',
                                      25.6,
                                    ),
                                  ),
                                ),
                                width: width,
                                height: 108,
                                isSelected: _selectedRole == role,
                                onTap: () {
                                  if (!_isLoading) {
                                    setState(() => _selectedRole = role);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Create Account',
                  height: 56,
                  arrow: SizedBox(
                    width: 20,
                    height: 20,
                    child: Center(child: _asset('arrow', 16)),
                  ),
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: AppTextStyles.bodySmallRegular,
                          ),
                          TextSpan(
                            text: 'Log In',
                            style: AppTextStyles.linkMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerTop + 56,
            child: ColoredBox(
              color: AppColors.background,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    top: headerTop,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: _asset('back', 19.2),
                      ),
                    ),
                  ),
                  Positioned(
                    top: headerTop + 12,
                    left: (media.size.width - 112) / 2,
                    child: SvgPicture.asset(
                      'assets/icons/register_progress.svg',
                      width: 112,
                      height: 20,
                    ),
                  ),
                  Positioned(
                    top: headerTop + 6,
                    right: 20,
                    child: Opacity(
                      opacity: .16,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Center(child: _asset('shuttle', 49.4)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
