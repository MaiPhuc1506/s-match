import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_colors.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  // ProviderScope của Riverpod để quản lý State sau này
  runApp(const ProviderScope(child: SMatchApp()));
}

class SMatchApp extends StatelessWidget {
  const SMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S-Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
