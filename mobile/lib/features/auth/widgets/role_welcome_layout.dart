import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import 'primary_button.dart';

enum WelcomeRole { player, courtOwner, admin }

/// Shared presentation of the three role welcome frames. Authentication and
/// destination routing remain in the existing screen wrappers.
class RoleWelcomeLayout extends StatelessWidget {
  const RoleWelcomeLayout({
    super.key,
    required this.role,
    required this.onContinue,
  });

  final WelcomeRole role;
  final VoidCallback onContinue;

  static const _user = 'assets/icons/welcome_user_feature.svg';
  static const _calendar = 'assets/icons/welcome_calendar.svg';
  static const _bars = 'assets/icons/welcome_skill_bars.svg';

  String get _assetPrefix => switch (role) {
    WelcomeRole.player => 'player',
    WelcomeRole.courtOwner => 'owner',
    WelcomeRole.admin => 'admin',
  };

  String get _title => switch (role) {
    WelcomeRole.player => 'Player',
    WelcomeRole.courtOwner => 'Court Owner',
    WelcomeRole.admin => 'Admin',
  };

  String get _tagline => switch (role) {
    WelcomeRole.player =>
      'Find players. Book courts.\nPlay more. Better together.',
    WelcomeRole.courtOwner => 'Manage your courts.\nGrow your business.',
    WelcomeRole.admin => 'Keep the community safe.\nEnsure a great experience.',
  };

  String get _note => switch (role) {
    WelcomeRole.player => 'Play\nConnect\nImprove',
    WelcomeRole.courtOwner => 'More Players\nMore\nPossibilities',
    WelcomeRole.admin => 'Monitor\nSupport\nBuild Trust',
  };

  String get _description => switch (role) {
    WelcomeRole.player =>
      'Join a vibrant badminton community\nand find your perfect match.',
    WelcomeRole.courtOwner =>
      'Easily manage your facility and\nreach more badminton players.',
    WelcomeRole.admin =>
      'Oversee the platform and support\na healthy badminton community.',
  };

  String get _roleIcon => switch (role) {
    WelcomeRole.player => 'assets/icons/welcome_user_hero.svg',
    WelcomeRole.courtOwner => 'assets/icons/welcome_court_hero.svg',
    WelcomeRole.admin => 'assets/icons/welcome_shield_hero.svg',
  };

  List<_WelcomeFeature> get _features => switch (role) {
    WelcomeRole.player => const [
      _WelcomeFeature(
        _user,
        'Find compatible players',
        'Based on skill, time and location',
      ),
      _WelcomeFeature(
        _calendar,
        'Book courts easily',
        'From trusted facilities',
      ),
      _WelcomeFeature(
        _bars,
        'Track your progress',
        'Build your reputation in the community',
      ),
    ],
    WelcomeRole.courtOwner => const [
      _WelcomeFeature(
        _calendar,
        'Manage courts & schedules',
        'Set time slots and pricing',
      ),
      _WelcomeFeature(
        _bars,
        'Track bookings & revenue',
        'Get insights and analytics',
      ),
      _WelcomeFeature(
        _user,
        'Attract more players',
        'Connect with an active community',
      ),
    ],
    WelcomeRole.admin => const [
      _WelcomeFeature(
        _user,
        'Manage user accounts',
        'Players, court owners and admins',
      ),
      _WelcomeFeature(
        _bars,
        'Monitor matchmaking activity',
        'Ensure fairness and safety',
      ),
      _WelcomeFeature(
        'assets/icons/welcome_shield_feature.svg',
        'View reports & statistics',
        'Gain insights for a better community',
      ),
    ],
  };

  TextStyle _text(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color,
  ) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isPlayer = role == WelcomeRole.player;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isPlayer ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final heroScale = width / 393;
            final headerHeight = 188 + 250 * heroScale;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(context, width, headerHeight, heroScale),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _IconBadge(asset: _roleIcon, diameter: 64),
                            const SizedBox(height: 3),
                            Text(
                              _title,
                              style: _text(
                                18,
                                24,
                                FontWeight.w700,
                                AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _description,
                              textAlign: TextAlign.center,
                              style: _text(
                                12,
                                17,
                                FontWeight.w400,
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Column(
                          children: [
                            for (var i = 0; i < _features.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _buildFeature(_features[i]),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      Center(
                        child: SvgPicture.asset(
                          'assets/icons/welcome_${_assetPrefix}_progress.svg',
                          width: 48,
                          height: 8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          math.max(28, media.padding.bottom),
                        ),
                        child: PrimaryButton(
                          text: 'Continue',
                          onPressed: onContinue,
                          arrow: SizedBox(
                            width: 20,
                            height: 20,
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/register_arrow.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(
    BuildContext context,
    double width,
    double height,
    double scale,
  ) {
    final isPlayer = role == WelcomeRole.player;
    final foreground = isPlayer ? Colors.white : AppColors.primaryDark;
    final colors = switch (role) {
      WelcomeRole.player => const [Color(0xFF05634F), Color(0xFF033D33)],
      WelcomeRole.courtOwner => const [Color(0xFFF0FAF5), Color(0xFFD1F0E5)],
      WelcomeRole.admin => const [Color(0xFFFCF5F2), Color(0xFFF5E3E0)],
    };
    final top = math.max(69.0, MediaQuery.paddingOf(context).top + 7);
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1, -.2),
                  end: const Alignment(1, .2),
                  colors: colors,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 188,
            height: 280 * scale,
            child: Image.asset(
              'assets/images/welcome_${_assetPrefix}_hero.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: (width - 520 * scale) / 2,
            top: 188 + 211 * scale,
            child: SvgPicture.asset(
              'assets/icons/welcome_sheet_arc.svg',
              width: 520 * scale,
              height: 180 * scale,
              excludeFromSemantics: true,
            ),
          ),
          Positioned(
            left: 28,
            top: top,
            child: Text(
              'Welcome to',
              style: _text(21, 28, FontWeight.w500, foreground),
            ),
          ),
          Positioned(
            left: 28,
            top: top + 27,
            child: Text(
              'S-Match',
              style: _text(38, 48, FontWeight.w700, foreground),
            ),
          ),
          Positioned(
            left: 28,
            top: top + 77,
            child: Text(
              _tagline,
              style: _text(14, 20, FontWeight.w400, foreground),
            ),
          ),
          Positioned(
            right: 19,
            top: top + 7,
            width: role == WelcomeRole.courtOwner ? 100 : 82,
            child: Text(
              _note,
              style: _text(
                14,
                19,
                FontWeight.w400,
                isPlayer ? const Color(0xFF80D1B8) : const Color(0xFF5EA894),
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(_WelcomeFeature feature) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      _IconBadge(asset: feature.asset, diameter: 44),
      const SizedBox(width: 12),
      Expanded(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 39),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                feature.title,
                style: _text(13, 18, FontWeight.w600, const Color(0xFF0D333D)),
              ),
              const SizedBox(height: 1),
              Text(
                feature.description,
                style: _text(11, 16, FontWeight.w400, const Color(0xFF7A7A7A)),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.asset, required this.diameter});
  final String asset;
  final double diameter;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: const BoxDecoration(
      color: AppColors.roleSelectedCard,
      shape: BoxShape.circle,
    ),
    child: Center(child: SvgPicture.asset(asset, excludeFromSemantics: true)),
  );
}

class _WelcomeFeature {
  const _WelcomeFeature(this.asset, this.title, this.description);
  final String asset;
  final String title;
  final String description;
}
