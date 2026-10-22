import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/edit_profile_screen.dart';
import 'package:mobile/features/auth/screens/skill_assessment_screen.dart';
import 'package:mobile/features/auth/screens/match_preferences_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';

import '../widgets/logout_dialog.dart';
import '../widgets/profile_skill_radar.dart';
import '../widgets/sprint2_presentation.dart';
import '../../../core/network/api_client.dart';
import '../services/auth_service.dart';
import '../services/player_profile_service.dart';

/// Player Profile — Figma frame 195:178 (393 × 852).
class PlayerProfileScreen extends StatefulWidget {
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateMap;
  final VoidCallback? onNavigateMatch;
  final VoidCallback? onNavigateFeedback;
  final VoidCallback? onNavigateProfile;

  const PlayerProfileScreen({
    super.key,
    this.onNavigateHome,
    this.onNavigateMap,
    this.onNavigateMatch,
    this.onNavigateFeedback,
    this.onNavigateProfile,
  });

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  OwnPlayerProfile? _profile;
  int _profileRequestId = 0;

  @override
  void initState() {
    super.initState();
    if (ApiClient.instance.token != null) _loadProfile();
  }

  Future<void> _loadProfile() async {
    final requestId = ++_profileRequestId;
    try {
      final profile = await PlayerProfileService.instance.getMyProfile();
      if (mounted && requestId == _profileRequestId) {
        setState(() => _profile = profile);
      }
    } on PlayerProfileException catch (error) {
      if (!mounted || requestId != _profileRequestId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(label: 'Thử lại', onPressed: _loadProfile),
        ),
      );
    }
  }

  String get _fullName =>
      _profile?.fullName ??
      (ApiClient.instance.token == null
          ? 'Phúc Mai'
          : AuthService.instance.currentUser?['fullName'] as String? ??
                'Player');
  String get _bio =>
      _profile?.bio ??
      (ApiClient.instance.token == null
          ? 'Badminton enthusiast. Always up for a friendly match and improving together! '
          : '');

  static const _background = Color(0xFFF7F8F5);
  static const _primary = Color(0xFF05644F);
  static const _brandText = Color(0xFF054D3F);
  static const _textPrimary = Color(0xFF142824);
  static const _textSecondary = Color(0xFF64716D);

  Future<void> _navigateDissolve(
    BuildContext context,
    Widget destination,
  ) async {
    final result = await Navigator.of(context).push<Object?>(
      PageRouteBuilder<Object?>(
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
    if (mounted && result is OwnPlayerProfile) {
      _profileRequestId++;
      setState(() => _profile = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        bottomNavigationBar: PlayerBottomNavigation(
          currentTab: PlayerNavTab.profile,
          onNavigateHome: widget.onNavigateHome,
          onNavigateMap: widget.onNavigateMap,
          onNavigateMatch: widget.onNavigateMatch,
          onNavigateFeedback: widget.onNavigateFeedback,
          onNavigateProfile: widget.onNavigateProfile,
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 393),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 242,
                    child: Sprint2CourtPhoto(),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 242,
                    child: ColoredBox(color: Color(0x4D003D32)),
                  ),
                  Positioned(
                    top: 210,
                    left: 0,
                    right: 0,
                    height: 60,
                    child: SvgPicture.asset(
                      'assets/icons/sprint2_profile_HeroCurvedTransition.svg',
                      fit: BoxFit.fill,
                    ),
                  ),
                  Positioned(
                    top: 118,
                    right: 31,
                    child: Opacity(
                      opacity: .7,
                      child: Image.asset(
                        'assets/images/skill_level_shuttle.png',
                        width: 88,
                        height: 88,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _buildAppBar(context),
                      _buildProfileContent(context),
                    ],
                  ),
                ],
              ),
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
                      size: 24,
                      lineHeight: 33,
                      color: Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _navigateDissolve(
                      context,
                      EditProfileScreen(initialProfile: _profile),
                    ),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SvgPicture.asset(
                        'assets/icons/sprint2_profile_Settings.svg',
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

  Widget _buildProfileContent(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileHeader(context),
        const SizedBox(height: 8),
        _buildQuickStats(context),
        const SizedBox(height: 8),
        _buildSkillOverview(context),
        const SizedBox(height: 8),
        _buildPlayingStyle(context),
        const SizedBox(height: 24),
        _buildLogoutButton(context),
        const SizedBox(height: 16),
      ],
    ),
  );

  Widget _buildProfileHeader(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () =>
        _navigateDissolve(context, EditProfileScreen(initialProfile: _profile)),
    child: SizedBox(
      height: 264 + (MediaQuery.sizeOf(context).width < 368 ? 17 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/sprint2_profile_AvatarPhoto.png',
                width: 104,
                height: 104,
              ),
            ),
          ),
          Positioned(
            top: 118,
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                        48) /
                    2 +
                32.5,
            child: const Sprint2CameraBadge(),
          ),
          Positioned(
            top: 148,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  _fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle(
                    size: 22,
                    lineHeight: 30,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDEFE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/sprint2_profile_Vector.svg',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Intermediate',
                            style: _textStyle(
                              size: 12,
                              lineHeight: 17,
                              weight: FontWeight.w500,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: '★',
                            style: TextStyle(color: Color(0xFFF5B72F)),
                          ),
                          const TextSpan(text: ' 4.6 (24)'),
                        ],
                      ),
                      style: _textStyle(
                        size: 14,
                        lineHeight: 19,
                        weight: FontWeight.w500,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '●  Da Nang, Vietnam',
                  style: _textStyle(
                    size: 12,
                    lineHeight: 17,
                    weight: FontWeight.w400,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _bio.isEmpty ? '' : '${_bio.trimRight()} ',
                      ),
                      if (_bio.isNotEmpty)
                        const TextSpan(
                          text: 'More',
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _textStyle(
                    size: 12,
                    lineHeight: 17,
                    weight: FontWeight.w400,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildQuickStats(BuildContext context) {
    return Container(
      width: 345,
      height: 88,
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C08291F),
            offset: Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                    80) *
                40 /
                313,
            top: -19,
            child: SvgPicture.asset('assets/icons/sprint2_profile_Vector.svg'),
          ),
          Positioned(
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                    80) *
                148 /
                313,
            top: -18,
            child: Text(
              '✓',
              style: _textStyle(
                size: 14,
                lineHeight: 19,
                weight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ),
          Positioned(
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                    80) *
                256 /
                313,
            top: -18,
            child: Text(
              '★',
              style: _textStyle(
                size: 14,
                lineHeight: 19,
                weight: FontWeight.w600,
                color: const Color(0xFFF5B72F),
              ),
            ),
          ),
          Positioned(
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                    80) *
                100 /
                313,
            top: -6,
            height: 48,
            child: const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFE7ECE9),
            ),
          ),
          Positioned(
            left:
                (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                    80) *
                212 /
                313,
            top: -6,
            height: 48,
            child: const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFE7ECE9),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: _StatItem(value: '24', label: 'Matches'),
              ),
              Expanded(
                child: _StatItem(
                  value: '18',
                  label: 'Completed',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BookingHistoryScreen(),
                      ),
                    );
                  },
                ),
              ),
              const Expanded(
                child: _StatItem(value: '4.6', label: 'Rating'),
              ),
            ],
          ),
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
        height: 216 - (PlayerBottomNavigation.heightFor(context) - 84),
        child: Column(
          children: [
            SizedBox(
              width: 345,
              height: 26,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Skill Overview',
                        style: _textStyle(
                          size: 16,
                          lineHeight: 22,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'View details',
                        style: _textStyle(
                          size: 12,
                          lineHeight: 17,
                          weight: FontWeight.w500,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 190 - (PlayerBottomNavigation.heightFor(context) - 84),
              child: const FittedBox(
                fit: BoxFit.contain,
                child: ProfileSkillRadar(refined: true),
              ),
            ),
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
          height: 80,
          color: const Color(0xFFE8F3EF),
          child: Stack(
            children: [
              Positioned(
                left: 12,
                top: 10,
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
                top: 10,
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
                top: 38,
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
              Positioned(
                right: 14,
                top: 25,
                child: Text(
                  '›',
                  style: _textStyle(
                    size: 24,
                    lineHeight: 33,
                    weight: FontWeight.w400,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () => showLogoutConfirmationDialog(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFFDE8E8), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: Color(0xFFE53935),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Đăng xuất',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE53935),
              ),
            ),
          ],
        ),
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
  const _StatItem({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: _PlayerProfileScreenState._textStyle(
                size: 22,
                lineHeight: 28,
                weight: FontWeight.w700,
                color: _PlayerProfileScreenState._brandText,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: _PlayerProfileScreenState._textStyle(
                size: 12,
                lineHeight: 17,
                weight: FontWeight.w400,
                color: _PlayerProfileScreenState._textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }
    return content;
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
      width: MediaQuery.sizeOf(context).width < 360 ? 80 : 94,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: _PlayerProfileScreenState._textStyle(
          size: 12,
          lineHeight: 17,
          weight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
