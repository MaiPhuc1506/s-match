import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/edit_profile_screen.dart';
import 'package:mobile/features/auth/screens/skill_assessment_screen.dart';
import 'package:mobile/features/auth/screens/match_preferences_screen.dart';

/// Player Profile — Figma frame 195:178 (393 × 852).
class PlayerProfileScreen extends StatelessWidget {
  const PlayerProfileScreen({super.key});

  static const _background = Color(0xFFF7F8F5);
  static const _primary = Color(0xFF05644F);
  static const _brandText = Color(0xFF054D3F);
  static const _textPrimary = Color(0xFF1C1C1C);
  static const _textSecondary = Color(0xFF6B6B6B);

  void _navigateDissolve(BuildContext context, Widget destination) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, animation, secondaryAnimation) {
          return destination;
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 393),
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _buildProfileContent(context)),
                _buildBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SizedBox(
      width: 393,
      height: 96,
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Profile',
                    style: _textStyle(
                      size: 22,
                      lineHeight: 30,
                      weight: FontWeight.w700,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        _navigateDissolve(context, const EditProfileScreen()),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SvgPicture.asset(
                        'assets/icons/profile_settings.svg',
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

  Widget _buildProfileContent(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 12),
          _buildQuickStats(),
          const SizedBox(height: 12),
          _buildSkillOverview(context),
          const SizedBox(height: 12),
          _buildPlayingStyle(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateDissolve(context, const EditProfileScreen()),
      child: SizedBox(
        width: 345,
        height: 236,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SvgPicture.asset(
                  'assets/icons/profile_hero_decoration.svg',
                  width: 345,
                  height: 124,
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned(
              left: 110.5,
              top: -4,
              child: Image.asset(
                'assets/images/profile_avatar.png',
                width: 124,
                height: 124,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              left: 205,
              top: 72,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 3),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/icons/profile_camera.svg',
                  width: 18,
                  height: 18,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 108,
              child: SizedBox(
                width: 345,
                height: 128,
                child: Column(
                  children: [
                    Text(
                      'Phúc Mai',
                      style: _textStyle(
                        size: 28,
                        lineHeight: 36,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 345,
                      height: 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 122,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDEFE7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/icons/profile_level_racket.svg',
                                  width: 18,
                                  height: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Intermediate',
                                  style: _textStyle(
                                    size: 14,
                                    lineHeight: 20,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '★ 4.6  (24 reviews)',
                            style: _textStyle(
                              size: 13,
                              lineHeight: 18,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '●  Da Nang, Vietnam',
                      style: _textStyle(
                        size: 13,
                        lineHeight: 18,
                        weight: FontWeight.w500,
                        color: _brandText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: 321,
                      height: 36,
                      child: Text(
                        'Badminton enthusiast. Always up for a friendly match\n'
                        'and improving together!   More',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                        style: _textStyle(
                          size: 13,
                          lineHeight: 18,
                          weight: FontWeight.w400,
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
    );
  }

  Widget _buildQuickStats() {
    return Container(
      width: 345,
      height: 88,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xB8FFFFFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C08291F),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(value: '24', label: 'Matches'),
          _StatItem(value: '18', label: 'Completed'),
          _StatItem(value: '4.6', label: 'Rating'),
        ],
      ),
    );
  }

  Widget _buildSkillOverview(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateDissolve(context, const SkillAssessmentScreen()),
      child: SizedBox(
        width: 345,
        height: 212,
        child: Column(
          children: [
            SizedBox(
              width: 345,
              height: 28,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Skill Overview',
                    style: _textStyle(
                      size: 20,
                      lineHeight: 28,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'View details',
                    style: _textStyle(
                      size: 13,
                      lineHeight: 18,
                      weight: FontWeight.w500,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const _SkillRadar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayingStyle(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateDissolve(context, const MatchPreferencesScreen()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 345,
          height: 72,
          color: const Color(0xE6EAF4F0),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 2,
                child: Image.asset(
                  'assets/images/profile_playing_style_racket.png',
                  width: 68.2,
                  height: 68.2,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                left: 68,
                top: 8,
                child: Text(
                  'Playing Style',
                  style: _textStyle(
                    size: 16,
                    lineHeight: 22,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const Positioned(
                left: 68,
                top: 34,
                child: Row(
                  children: [
                    _StyleChip(
                      label: 'Doubles',
                      background: _primary,
                      foreground: Colors.white,
                    ),
                    SizedBox(width: 8),
                    _StyleChip(
                      label: 'Offensive',
                      background: Color(0xFFF6DEDC),
                      foreground: Color(0xFF924A45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const items = [
      ('assets/icons/profile_nav_home.svg', 'Home', false),
      ('assets/icons/profile_nav_courts.svg', 'Courts', false),
      ('assets/icons/profile_nav_match.svg', 'Match', false),
      ('assets/icons/profile_nav_messages.svg', 'Messages', false),
      ('assets/icons/profile_nav_user.svg', 'Profile', true),
    ];

    return Container(
      width: 393,
      height: 84,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDDE5E1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items
            .map(
              (item) => _NavigationItem(
                asset: item.$1,
                label: item.$2,
                active: item.$3,
              ),
            )
            .toList(),
      ),
    );
  }

  static TextStyle _textStyle({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    Color color = _textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: PlayerProfileScreen._textStyle(
              size: 22,
              lineHeight: 28,
              weight: FontWeight.w700,
              color: PlayerProfileScreen._brandText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PlayerProfileScreen._textStyle(
              size: 13,
              lineHeight: 18,
              weight: FontWeight.w400,
              color: PlayerProfileScreen._textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillRadar extends StatelessWidget {
  const _SkillRadar();

  TextStyle get _labelStyle => PlayerProfileScreen._textStyle(
    size: 10.67,
    lineHeight: 14.222,
    weight: FontWeight.w500,
    color: const Color(0xFF4F5B56),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _svg(
            'assets/icons/profile_radar_grid_outer.svg',
            left: 33.82,
            top: 26.67,
            width: 92.38,
            height: 106.67,
          ),
          _svg(
            'assets/icons/profile_radar_grid_middle.svg',
            left: 49.20,
            top: 44.44,
            width: 61.58,
            height: 71.11,
          ),
          _svg(
            'assets/icons/profile_radar_grid_inner.svg',
            left: 64.60,
            top: 62.22,
            width: 30.79,
            height: 35.56,
          ),
          _svg(
            'assets/icons/profile_radar_data.svg',
            left: 44.59,
            top: 36.44,
            width: 70.82,
            height: 87.11,
          ),
          Positioned(
            left: 64,
            top: 0,
            child: Text('Smash', style: _labelStyle),
          ),
          Positioned(
            left: 120.89,
            top: 35.56,
            child: Text('Defense', style: _labelStyle),
          ),
          Positioned(
            left: 119.11,
            top: 115.56,
            child: Text('Net Play', style: _labelStyle),
          ),
          Positioned(
            left: 60.44,
            top: 144,
            child: Text('Stamina', style: _labelStyle),
          ),
          Positioned(
            left: 0,
            top: 115.56,
            child: Text('Footwork', style: _labelStyle),
          ),
          Positioned(
            left: 3.56,
            top: 35.56,
            child: Text('Serve', style: _labelStyle),
          ),
        ],
      ),
    );
  }

  Widget _svg(
    String asset, {
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: SvgPicture.asset(asset, width: width, height: height),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PlayerProfileScreen._textStyle(
          size: 14,
          lineHeight: 20,
          weight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.asset,
    required this.label,
    required this.active,
  });

  final String asset;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? PlayerProfileScreen._brandText
        : PlayerProfileScreen._textSecondary;

    return SizedBox(
      width: 64,
      height: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Center(
              child: Opacity(
                opacity: active ? 1 : 0.52,
                child: SvgPicture.asset(asset, width: 17.6, height: 17.6),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PlayerProfileScreen._textStyle(
              size: 12,
              lineHeight: 16,
              weight: FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
