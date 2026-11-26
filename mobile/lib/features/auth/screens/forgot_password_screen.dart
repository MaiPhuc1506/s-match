import '../../../core/theme/app_motion_widgets.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_motion.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final email = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RecoveryLayout(
    title: 'Forgot Password?',
    illustration: 'mail',
    stage: 2,
    description: 'Enter your email and we’ll send you\na verification code.',
    action: 'Send Code',
    error: error,
    onAction: () async {
      if (busy) return;
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
        setState(() => error = 'Enter a valid email address.');
        return;
      }
      setState(() {
        busy = true;
        error = null;
      });
      try {
        await ApiClient.instance.dio.post(
          '/auth/password-recovery/request',
          data: {'email': email.text.trim()},
          options: Options(receiveTimeout: const Duration(seconds: 30)),
        );
        if (!context.mounted) return;
        Navigator.of(context).push(
          AppMotion.route(
            VerifyCodeScreen(email: email.text.trim()),
            name: '/verify-code',
          ),
        );
      } on DioException catch (e) {
        if (mounted) {
          setState(
            () => error = e.response?.statusCode == 503
                ? 'Email recovery is not configured yet.'
                : 'Unable to send code. Please try again.',
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    },
    children: [
      CustomTextField(
        controller: email,
        hintText: 'Email',
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        leading: SvgPicture.asset(
          'assets/icons/register_mail.svg',
          width: 16,
          height: 16,
        ),
      ),
    ],
  );
}

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, this.email = ''});
  final String email;
  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final fields = List.generate(6, (_) => TextEditingController());
  final focus = List.generate(6, (_) => FocusNode());
  Timer? timer;
  int seconds = 60;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => seconds--);
      if (seconds <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final c in fields) {
      c.dispose();
    }
    for (final n in focus) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RecoveryLayout(
    title: 'Verify Code',
    illustration: 'shield',
    stage: 3,
    description: 'Enter the 6-digit code sent\nto your email.',
    action: 'Verify',
    error: error,
    onAction: () async {
      if (busy) return;
      final code = fields.map((c) => c.text).join();
      if (code.length != 6 || widget.email.isEmpty) {
        setState(() => error = 'Enter the 6-digit verification code.');
        return;
      }
      setState(() {
        busy = true;
        error = null;
      });
      try {
        final response = await ApiClient.instance.dio.post(
          '/auth/password-recovery/verify',
          data: {'email': widget.email, 'code': code},
        );
        final token = (response.data as Map)['resetToken'];
        if (token is! String || token.isEmpty) throw const FormatException();
        if (!context.mounted) return;
        Navigator.of(context).push(
          AppMotion.route(
            CreateNewPasswordScreen(email: widget.email, resetToken: token),
            name: '/new-password',
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() => error = 'Invalid or expired code. Please try again.');
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    },
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            SizedBox(
              width: 38,
              height: 56,
              child: TextField(
                key: ValueKey('otp-$i'),
                controller: fields[i],
                focusNode: focus[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: AppTextStyles.titleBold.copyWith(
                  fontSize: 20,
                  height: 1.4,
                ),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) focus[i + 1].requestFocus();
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      TextButton(
        onPressed: seconds > 0
            ? null
            : () async {
                if (busy || widget.email.isEmpty) return;
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await ApiClient.instance.dio.post(
                    '/auth/password-recovery/request',
                    data: {'email': widget.email},
                    options: Options(
                      receiveTimeout: const Duration(seconds: 30),
                    ),
                  );
                  if (mounted) {
                    setState(() => seconds = 60);
                    _startTimer();
                  }
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error = 'Unable to resend code. Please try again.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: Text(
          'Didn’t receive a code?  ${seconds > 0 ? 'Resend (${seconds}s)' : 'Resend'}',
          style: AppTextStyles.bodySmallRegular,
        ),
      ),
    ],
  );
}

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({
    super.key,
    this.email = '',
    this.resetToken = '',
  });
  final String email, resetToken;
  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final password = TextEditingController(), confirm = TextEditingController();
  String? error;
  bool busy = false;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  List<bool> get checks => [
    password.text.length >= 8,
    RegExp(r'[a-zA-Z]').hasMatch(password.text) &&
        RegExp(r'\d').hasMatch(password.text),
    RegExp(r'[^a-zA-Z0-9]').hasMatch(password.text),
  ];
  @override
  Widget build(BuildContext context) => _RecoveryLayout(
    title: 'Create New Password',
    illustration: 'lock',
    stage: 3,
    description: 'Choose a strong password\nfor your account.',
    action: 'Reset Password',
    error: error,
    onAction: () async {
      if (checks.contains(false) || confirm.text != password.text) {
        setState(
          () => error =
              'Meet all password requirements and confirm the same password.',
        );
        return;
      }
      if (busy || widget.email.isEmpty || widget.resetToken.isEmpty) {
        if (!busy) setState(() => error = 'Please restart password recovery.');
        return;
      }
      setState(() {
        busy = true;
        error = null;
      });
      try {
        await ApiClient.instance.dio.post(
          '/auth/password-recovery/reset',
          data: {
            'email': widget.email,
            'resetToken': widget.resetToken,
            'password': password.text,
          },
        );
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Password updated'),
            content: const Text(
              'Your password has been updated. Please sign in again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back to Log In'),
              ),
            ],
          ),
        );
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => error =
                'Unable to reset password. The request may have expired.',
          );
        }
      } finally {
        if (mounted) setState(() => busy = false);
      }
    },
    children: [
      for (final (controller, hint) in [
        (password, 'New Password'),
        (confirm, 'Confirm Password'),
      ]) ...[
        CustomTextField(
          controller: controller,
          hintText: hint,
          prefixIcon: Icons.lock_outline,
          isPassword: true,
          leading: SvgPicture.asset(
            'assets/icons/register_lock.svg',
            width: 16,
            height: 16,
          ),
        ),
        const SizedBox(height: 14),
      ],
      ValueListenableBuilder(
        valueListenable: password,
        builder: (_, _, _) => Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      checks[i]
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      size: 16,
                      color: checks[i]
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          'At least 8 characters',
                          'Include letters and numbers',
                          'Include a special character',
                        ][i],
                        style: AppTextStyles.bodySmallRegular,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _RecoveryLayout extends StatelessWidget {
  const _RecoveryLayout({
    required this.title,
    required this.illustration,
    required this.stage,
    required this.description,
    required this.action,
    required this.onAction,
    required this.children,
    this.error,
  });
  final String title, illustration, description, action;
  final int stage;
  final String? error;
  final VoidCallback onAction;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  SizedBox(
                    height: 100,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top.clamp(44, 62),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: () => Navigator.maybePop(context),
                                icon: SvgPicture.asset(
                                  'assets/icons/register_back.svg',
                                  width: 19.2,
                                  height: 19.2,
                                ),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < stage
                                        ? AppColors.primary
                                        : const Color(0xFFB8BFBD),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: title == 'Create New Password' ? 50 : 58),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AppStaggeredColumn(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: AppColors.illustrationCircle,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/${illustration == 'shield' ? 'welcome_shield_hero' : 'register_$illustration'}.svg',
                            width: 35.2,
                            height: 35.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleBold.copyWith(
                            fontSize: 24,
                            height: 32 / 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmallRegular.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...children,
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                error!,
                                style: AppTextStyles.linkMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: PrimaryButton(text: action, onPressed: onAction),
                  ),
                  if (action == 'Send Code')
                    TextButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: Text(
                        'Back to Log In',
                        style: AppTextStyles.linkMedium,
                      ),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
