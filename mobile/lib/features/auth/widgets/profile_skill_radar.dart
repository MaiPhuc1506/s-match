import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared Profile radar. Refined presentation reuses the exact Sprint 2 Figma radar.
class ProfileSkillRadar extends StatelessWidget {
  const ProfileSkillRadar({
    super.key,
    this.refined = false,
    this.assessment = false,
  });
  final bool refined;
  final bool assessment;

  TextStyle get _labelStyle => GoogleFonts.plusJakartaSans(
    fontSize: 10.67,
    height: 14.222 / 10.67,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: const Color(0xFF4F5B56),
  );

  @override
  Widget build(BuildContext context) {
    if (refined || assessment) return _refined();
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

  Widget _refined() {
    final scale = assessment ? 264 / 228 : 1.0;
    return SizedBox(
      width: 228 * scale,
      height: 190 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _svg(
            assessment
                ? 'assets/icons/sprint2_skill_RadarEditableGridAndSkillData.svg'
                : 'assets/sprint7/recommendation/profile_radar.svg',
            left: 28.5 * scale,
            top: 7.6 * scale,
            width: 171 * scale,
            height: 171 * scale,
          ),
          for (final axis in const [
            ('Smash', 95.95, 0.0),
            ('Defense', 184.3, 40.85),
            ('Net Play', 182.4, 133.0),
            ('Stamina', 91.2, 172.9),
            ('Footwork', 0.0, 133.0),
            ('Serve', 2.85, 40.85),
          ])
            Positioned(
              left: axis.$2 * scale,
              top: axis.$3 * scale,
              child: Text(
                axis.$1,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: assessment ? 14.3 : 11.4,
                  height: assessment ? 19.8 / 14.3 : 15.2 / 11.4,
                  color: const Color(0xFF64716D),
                ),
              ),
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
