import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_colors.dart';
import 'dev/presentation/dev_overlay.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/services/auth_service.dart';
import 'main.dart'; // Dùng để fallback an toàn sang ứng dụng thật nếu vô tình chạy release

/// Entry point dành riêng cho chế độ Developer Testing Hub:
/// Chạy lệnh: `flutter run -t lib/main_dev.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // BẢO VỆ PHÁT HÀNH SẢN XUẤT (Release Guard):
  // Nếu vô tình build với cấu hình release, chế độ Developer Mode sẽ tự động
  // chuyển hướng về ứng dụng thông thường, không để lộ Testing Hub ra bên ngoài.
  if (!kDebugMode) {
    runApp(const ProviderScope(child: SMatchApp()));
    return;
  }

  // OAuth client IDs are public identifiers, not client secrets.
  AuthService.instance.devGoogleServerClientId = '873730457312-cbbu48ccp9cmh9trtn7pd8db6ht89vmk.apps.googleusercontent.com';
  AuthService.instance.devGoogleIosClientId = '873730457312-736dj9i1e29nfvf4ertu4c8408rl5a52.apps.googleusercontent.com';
  runApp(ProviderScope(child: const DevTestingHubApp()));
}

class DevTestingHubApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  const DevTestingHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navKey,
      title: 'S-Match Dev Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFAFBF9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: const Color(0xFFFAFBF9),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: AppColors.primaryDark),
        ),
      ),
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: DevGlobalOverlay(
            navKey: navKey,
            child: child ?? const SizedBox(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
