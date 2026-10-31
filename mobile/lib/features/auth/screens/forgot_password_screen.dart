import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    onAction: () {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.text.trim())) {
        setState(() => error = 'Enter a valid email address.');
        return;
      }
      Navigator.of(context).push(
        AppMotion.route(
          VerifyCodeScreen(email: email.text.trim()),
          name: '/verify-code',
        ),
      );
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
  final fields = List.generate(4, (_) => TextEditingController());
  final focus = List.generate(4, (_) => FocusNode());
  Timer? timer;
  int seconds = 58;
  String? error;
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
    description: 'Enter the 4-digit code sent\nto your email.',
    action: 'Verify',
    error: error,
    previewMessage: 'UI preview · No email sent · Demo code: 2846',
    onAction: () {
      if (fields.map((c) => c.text).join() != '2846') {
        setState(
          () => error = 'Use demo code 2846 to preview the next screen.',
        );
        return;
      }
      Navigator.of(context).push(
        AppMotion.route(const CreateNewPasswordScreen(), name: '/new-password'),
      );
    },
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            SizedBox(
              width: 56,
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
                  if (v.isNotEmpty && i < 3) focus[i + 1].requestFocus();
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
            : () {
                setState(() => seconds = 58);
                _startTimer();
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
  const CreateNewPasswordScreen({super.key});
  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  final password = TextEditingController(), confirm = TextEditingController();
  String? error;
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Preview complete'),
          content: const Text(
            'Password recovery has no backend API yet. Your real password has not changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Log In'),
            ),
          ],
        ),
      );
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    this.previewMessage =
        'UI preview · Password recovery API is not available yet',
  });
  final String title, illustration, description, action, previewMessage;
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
                    child: Column(
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
                        const SizedBox(height: 12),
                        Text(
                          previewMessage,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmallRegular.copyWith(
                            fontSize: 10,
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
