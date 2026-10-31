import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: SMatchApp()));
}

class SMatchApp extends StatelessWidget {
  const SMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'S-Match',
      debugShowCheckedModeBanner: false,
      theme: SMatchTheme.light,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
