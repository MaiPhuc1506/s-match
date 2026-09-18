import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/login_screen.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _navigated = false;
  bool _assetsPrecached = false;

  // Tổng thời gian chuỗi animation: 4800ms
  static const int _totalDurationMs = 4800;

  // Bảng màu chuẩn Figma & HTML
  static const Color _courtDeep = Color(0xFF054D3F);
  static const Color _courtMid = Color(0xFF05644F);
  static const Color _courtLight = Color(0xFF08725B);
  static const Color _accentRed = Color(0xFF924A45);
  static const Color _paper = Color(0xFFF7F8F5);

  @override
  void initState() {
    super.initState();

    // Cho phép giao diện tràn qua Status bar và Navigation bar của máy ảo
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    );

    _controller.addListener(() {
      final elapsed = _controller.value * _totalDurationMs;
      if (elapsed >= _totalDurationMs && !_navigated) {
        _navigateToLogin();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_assetsPrecached) return;
    _assetsPrecached = true;

    _prepareSplash();
  }

  Future<void> _prepareSplash() async {
    try {
      await Future.wait([
        for (int i = 1; i <= 6; i++)
          precacheImage(
            AssetImage('assets/images/splash/ntm-frame-$i.png'),
            context,
          ),
        precacheImage(
          const AssetImage(
            'assets/images/splash/s-match-audience-background-fullbleed.jpg',
          ),
          context,
        ),
      ]);
    } catch (_) {}

    if (!mounted) return;
    _controller.forward();
  }

  void _navigateToLogin() {
    _navigated = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _courtDeep,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 390,
            height: 844,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final elapsed = _controller.value * _totalDurationMs;
                return Stack(
                  children: [
                    // 1. Nền Gradient sân cầu
                    _buildCourtGradient(),

                    // 2. Ảnh khán đài + vạch sân
                    _buildAudienceAndLines(elapsed),

                    // 3. Vòng sáng Halo sau lưng vận động viên
                    _buildHalo(elapsed),

                    // 4. Vận động viên Nguyễn Tiến Minh (chuyển động nội suy 60 FPS)
                    _buildAthlete(elapsed),

                    // 5. Quả cầu lông & vệt bay
                    _buildShuttlecock(elapsed),

                    // 6. Tia chớp Flash khi chạm vợt
                    _buildFlash(elapsed),

                    // 7. Lớp Logo S-Match kết thúc
                    _buildLogoLayer(elapsed),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. NỀN GRADIENT ---
  Widget _buildCourtGradient() {
    return Container(
      width: 390,
      height: 844,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.02),
          radius: 0.95,
          colors: [_courtLight, _courtMid, _courtDeep],
          stops: [0.0, 0.54, 1.0],
        ),
      ),
    );
  }

  // --- 2. ẢNH KHÁN ĐÀI & ĐƯỜNG KẺ SÂN ---
  Widget _buildAudienceAndLines(double elapsed) {
    double audienceOpacity = 0.82;
    double courtLinesOpacity = 0.07;
    if (elapsed >= 2480) {
      final t = ((elapsed - 2480) / 550).clamp(0.0, 1.0);
      audienceOpacity = 0.82 * (1.0 - t);
      courtLinesOpacity = 0.07 - (0.045 * t);
    }

    return Stack(
      children: [
        if (audienceOpacity > 0.01)
          Opacity(
            opacity: audienceOpacity,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x33054D3F),
                BlendMode.multiply,
              ),
              child: Image.asset(
                'assets/images/splash/s-match-audience-background-fullbleed.jpg',
                width: 390,
                height: 844,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Opacity(
          opacity: courtLinesOpacity,
          child: CustomPaint(
            size: const Size(390, 844),
            painter: _CourtLinesPainter(), // <-- Vẽ 2 vạch xiên hình thang
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 844 * 0.61,
          child: Container(
            height: 1,
            color: _paper.withOpacity(audienceOpacity > 0.1 ? 0.14 : 0.02),
          ),
        ),
      ],
    );
  }

  // --- 3. VÒNG SÁNG HALO ---
  Widget _buildHalo(double elapsed) {
    if (elapsed < 60 || elapsed > 2500) return const SizedBox.shrink();

    double haloOpacity = 0.0;
    if (elapsed >= 60 && elapsed < 460) {
      haloOpacity = ((elapsed - 60) / 400).clamp(0.0, 1.0);
    } else if (elapsed >= 460 && elapsed < 2180) {
      haloOpacity = 1.0;
    } else if (elapsed >= 2180) {
      haloOpacity = (1.0 - ((elapsed - 2180) / 300)).clamp(0.0, 1.0);
    }

    double scale = 1.0;
    if (elapsed >= 1510 && elapsed <= 1930) {
      final p = (elapsed - 1510) / 420;
      scale = 1.0 + 0.08 * math.sin(p * math.pi);
    }

    return Positioned(
      left: 195 - 115,
      bottom: 844 * 0.30,
      child: Opacity(
        opacity: haloOpacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_paper.withOpacity(0.14), Colors.transparent],
                stops: const [0.0, 0.70],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. VẬN ĐỘNG VIÊN NGUYỄN TIẾN MINH (NỘI SUY CHUYỂN ĐỘNG 60 FPS) ---
  Widget _buildAthlete(double elapsed) {
    if (elapsed < 60 || elapsed > 2500) return const SizedBox.shrink();

    int activeFrame = 1;
    Offset translate = const Offset(-48, 12);
    double scale = 0.94;
    double opacity = 1.0;

    // 0 -> 310ms: Fade in vận động viên
    if (elapsed < 310) {
      opacity = ((elapsed - 60) / 250).clamp(0.0, 1.0);
    }

    // NỘI SUY TỌA ĐỘ VÀ POSE THEO TIMELINE CHUẨN:
    if (elapsed >= 60 && elapsed < 540) {
      // Pose 1: Bắt đầu lấy đà
      activeFrame = 1;
      final p = ((elapsed - 60) / 480).clamp(0.0, 1.0);
      translate = Offset.lerp(const Offset(-52, 14), const Offset(-48, 12), p)!;
      scale = 0.94;
    } else if (elapsed >= 540 && elapsed < 890) {
      // Pose 2: Sải chân bước 2 (trượt lướt mượt mà)
      activeFrame = 2;
      final p = ((elapsed - 540) / 350).clamp(0.0, 1.0);
      final curve = Curves.easeInOut.transform(p);
      translate = Offset.lerp(
        const Offset(-48, 12),
        const Offset(-34, 7),
        curve,
      )!;
      scale = 0.94 + 0.03 * curve;
    } else if (elapsed >= 890 && elapsed < 1180) {
      // Pose 3: Dậm đà chân
      activeFrame = 3;
      final p = ((elapsed - 890) / 290).clamp(0.0, 1.0);
      final curve = Curves.easeInOut.transform(p);
      translate = Offset.lerp(
        const Offset(-34, 7),
        const Offset(-17, 10),
        curve,
      )!;
      scale = 0.97 + 0.01 * curve;
    } else if (elapsed >= 1180 && elapsed < 1510) {
      // Pose 4: Bật người lên không trung (Jump prep)
      activeFrame = 4;
      final p = ((elapsed - 1180) / 330).clamp(0.0, 1.0);
      final curve = Curves.easeOutCubic.transform(p);
      translate = Offset.lerp(
        const Offset(-17, 10),
        const Offset(0, -24),
        curve,
      )!;
      scale = 0.98 + 0.02 * curve;
    } else if (elapsed >= 1510 && elapsed < 1750) {
      // Pose 5: Bay vút lên đỉnh điểm thực hiện đập cầu (Jump Smash Apex - nâng lên -70px)
      activeFrame = 5;
      final p = ((elapsed - 1510) / 240).clamp(0.0, 1.0);
      final curve = Curves.easeOutCubic.transform(p);
      translate = Offset.lerp(
        const Offset(0, -24),
        const Offset(10, -70),
        curve,
      )!;
      scale = 1.0 + 0.04 * curve;
    } else if (elapsed >= 1750 && elapsed < 2180) {
      // Pose 6: Vung vợt kết thúc và hạ người tiếp đất (+9px)
      activeFrame = 6;
      final p = ((elapsed - 1750) / 430).clamp(0.0, 1.0);
      final curve = Curves.easeInCubic.transform(p);
      translate = Offset.lerp(
        const Offset(10, -70),
        const Offset(28, 9),
        curve,
      )!;
      scale = 1.04 - 0.06 * curve;
    } else if (elapsed >= 2180) {
      // Impact phase: Vận động viên lướt nhẹ và mờ dần
      activeFrame = 6;
      final p = ((elapsed - 2180) / 220).clamp(0.0, 1.0);
      opacity = (1.0 - p).clamp(0.0, 1.0);
      translate = Offset.lerp(const Offset(28, 9), const Offset(42, -8), p)!;
      scale = 0.98 + 0.04 * p;
    }

    return Positioned(
      left: 195 - 75,
      bottom: 844 * 0.27,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: translate,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 150,
              height: 232,
              // Nạp sẵn toàn bộ 6 frame để chuyển đổi tức thì không giật
              child: Stack(
                children: [
                  for (int i = 1; i <= 6; i++)
                    Opacity(
                      opacity: activeFrame == i ? 1.0 : 0.0,
                      child: Image.asset(
                        'assets/images/splash/ntm-frame-$i.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. QUẢ CẦU LÔNG & VỆT BAY ---
  Widget _buildShuttlecock(double elapsed) {
    if (elapsed < 1510 || elapsed > 2430) return const SizedBox.shrink();

    const double originX = 390 * 0.44 + 13;
    const double originBottom = 844 * 0.59 + 6;

    double dx = 0;
    double dy = 0;
    double rotation = 22 * math.pi / 180;
    double scale = 1.0;
    double shuttleOpacity = 1.0;
    bool showTrail = false;

    if (elapsed >= 1510 && elapsed < 1750) {
      // Tiếp xúc đỉnh vợt ở Frame 5
      dx = 0;
      dy = 0;
      rotation = 22 * math.pi / 180;
      scale = 1.0;
      shuttleOpacity = 1.0;
    } else if (elapsed >= 1750 && elapsed <= 2430) {
      // Quả cầu bay vút chéo góc sau cú đập ở Frame 6
      final flyTotalMs = 2430 - 1750;
      final progress = ((elapsed - 1750) / flyTotalMs).clamp(0.0, 1.0);

      if (progress < 0.34) {
        dx = 0;
        dy = 0;
        rotation = 22 * math.pi / 180;
        scale = 1.0;
        shuttleOpacity = 1.0;
      } else {
        final flyP = (progress - 0.34) / 0.66;
        final curvedP = Curves.easeInCubic.transform(flyP);
        dx = 210 * curvedP;
        dy = 155 * curvedP;
        rotation = (22 + 36 * curvedP) * math.pi / 180;
        scale = 1.0 - 0.24 * curvedP;
        shuttleOpacity = (1.0 - curvedP).clamp(0.0, 1.0);
        showTrail = true;
      }
    }

    return Positioned(
      left: originX,
      bottom: originBottom,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: shuttleOpacity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (showTrail)
                    Positioned(
                      right: 10,
                      top: 7,
                      child: Transform.rotate(
                        angle: 34 * math.pi / 180,
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 78,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0x28F7F8F5),
                                Color(0xADF7F8F5),
                              ],
                              stops: [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(
                      painter: _ShuttlecockPainter(
                        featherColor: _paper,
                        corkColor: _accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 6. TIA CHỚP FLASH ---
  Widget _buildFlash(double elapsed) {
    if (elapsed < 1750 || elapsed > 1880) return const SizedBox.shrink();

    final flashP = ((elapsed - 1750) / 130).clamp(0.0, 1.0);
    final flashOpacity = 0.62 * (1.0 - flashP);

    return Positioned(
      left: 390 * 0.44 + 13 - 15,
      top: 844 * 0.41 - 6 - 15,
      child: Opacity(
        opacity: flashOpacity,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Color(0xD1F7F8F5),
                Color(0x40F7F8F5),
                Colors.transparent,
              ],
              stops: [0.10, 0.28, 0.68],
            ),
          ),
        ),
      ),
    );
  }

  // --- 7. LỚP LOGO S-MATCH KẾT THÚC ---
  Widget _buildLogoLayer(double elapsed) {
    if (elapsed < 2740) return const SizedBox.shrink();

    final logoProgress = ((elapsed - 2740) / 520).clamp(0.0, 1.0);
    final curvedLogo = Curves.easeOutCubic.transform(logoProgress);
    final logoOpacity = curvedLogo;
    final translateY = 8.0 * (1.0 - curvedLogo);

    final loaderTime = (elapsed - 2740) % 1100;
    final loaderProgress = loaderTime / 1100;

    return Positioned.fill(
      child: Opacity(
        opacity: logoOpacity,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon quả cầu S-Match nghiêng 35 độ
              Transform.rotate(
                angle: 35 * math.pi / 180,
                child: SvgPicture.asset(
                  'assets/images/shuttlecock.svg',
                  width: 52,
                  height: 52,
                  colorFilter: const ColorFilter.mode(_paper, BlendMode.srcIn),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'S-Match',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 36 / 28,
                  color: _paper,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Play More\nBetter More',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 20 / 14,
                  color: _paper,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 70,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withOpacity(0.15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -28 + (98 * loaderProgress),
                        top: 0,
                        bottom: 0,
                        width: 28,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: _paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM PAINTERS ---

class _ShuttlecockPainter extends CustomPainter {
  final Color featherColor;
  final Color corkColor;

  _ShuttlecockPainter({required this.featherColor, required this.corkColor});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 24.0;
    final scaleY = size.height / 24.0;

    final featherPath = Path()
      ..moveTo(12 * scaleX, 2 * scaleY)
      ..lineTo(6 * scaleX, 13 * scaleY)
      ..lineTo(18 * scaleX, 13 * scaleY)
      ..close();

    final featherPaint = Paint()
      ..color = featherColor.withOpacity(0.95)
      ..style = PaintingStyle.fill;
    canvas.drawPath(featherPath, featherPaint);

    final corkPaint = Paint()
      ..color = corkColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(12 * scaleX, 16 * scaleY),
      3.4 * scaleX,
      corkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xAEF7F8F5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.30),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.70),
      Offset(size.width, size.height * 0.70),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.92),
      Offset(size.width * 0.35, size.height * 0.30),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.84, size.height * 0.92),
      Offset(size.width * 0.65, size.height * 0.30),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
