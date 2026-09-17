import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class SkillAssessmentScreen extends StatelessWidget {
  const SkillAssessmentScreen({super.key});

  static const Color _background = Color(0xFFF7F8F5);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF53605B);
  static const Color _danger = Color(0xFF924A45);

  TextStyle _style({
    required double size,
    required FontWeight weight,
    required double lineHeight,
    Color color = _textPrimary,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 393),
              child: Column(
                children: [
                  _buildAppBar(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Column(
                        children: [
                          _buildLevelCard(),
                          const SizedBox(height: 12),
                          _buildRadarCard(),
                          const SizedBox(height: 12),
                          _buildBreakdown(),
                          const SizedBox(height: 12),
                          _buildRetakeButton(),
                        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 22,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Skill Assessment',
                      textAlign: TextAlign.center,
                      style: _style(
                        size: 22,
                        weight: FontWeight.w700,
                        lineHeight: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard() {
    return Container(
      width: 345,
      height: 144,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF05644F), Color(0xFF087A61)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2408291F),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 24,
            child: Opacity(
              opacity: 0.70,
              child: Image.asset(
                'assets/images/skill_level_shuttle.png',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: 16,
            child: SizedBox(
              width: 235,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BADMINTON LEVEL',
                    style: _style(
                      size: 11,
                      weight: FontWeight.w600,
                      lineHeight: 15,
                      color: Colors.white,
                      letterSpacing: 1.32,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Intermediate',
                    style: _style(
                      size: 28,
                      weight: FontWeight.w700,
                      lineHeight: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level 3.4  •  Solid foundation\n'
                    'Ready for longer, faster rallies.',
                    style: _style(
                      size: 14,
                      weight: FontWeight.w500,
                      lineHeight: 20,
                      color: Colors.white,
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

  Widget _buildRadarCard() {
    return SizedBox(
      width: 345,
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skill Breakdown',
            style: _style(size: 20, weight: FontWeight.w600, lineHeight: 28),
          ),
          const SizedBox(height: 8),
          const Center(child: _SkillRadar()),
        ],
      ),
    );
  }

  Widget _buildBreakdown() {
    const skills = [
      ('Smash', 4.0),
      ('Serve', 3.0),
      ('Defense', 3.5),
      ('Footwork', 4.0),
      ('Net Play', 3.0),
      ('Stamina', 3.5),
    ];

    return SizedBox(
      width: 345,
      height: 164,
      child: Column(
        children: [
          for (int index = 0; index < skills.length; index++) ...[
            _SkillProgressRow(
              label: skills[index].$1,
              value: skills[index].$2,
              labelStyle: _style(
                size: 13,
                weight: FontWeight.w600,
                lineHeight: 18,
              ),
              valueStyle: _style(
                size: 13,
                weight: FontWeight.w500,
                lineHeight: 18,
                color: _textSecondary,
              ),
            ),
            if (index != skills.length - 1) const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildRetakeButton() {
    return SizedBox(
      width: 345,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          // Sau này mở lại flow câu hỏi đánh giá kỹ năng.
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _danger,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, size: 21, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Retake Assessment',
              style: _style(
                size: 15,
                weight: FontWeight.w600,
                lineHeight: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillRadar extends StatelessWidget {
  const _SkillRadar();

  TextStyle _labelStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 15 / 11,
      color: const Color(0xFF1C1C1C),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 196,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            'assets/icons/profile_radar_grid_outer.svg',
            width: 148,
            height: 148,
          ),
          SvgPicture.asset(
            'assets/icons/profile_radar_grid_middle.svg',
            width: 112,
            height: 112,
          ),
          SvgPicture.asset(
            'assets/icons/profile_radar_grid_inner.svg',
            width: 72,
            height: 72,
          ),
          SvgPicture.asset(
            'assets/icons/profile_radar_data.svg',
            width: 148,
            height: 148,
          ),
          Positioned(
            top: 0,
            child: Text(
              'Smash\n4.0',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
          Positioned(
            right: -14,
            top: 48,
            child: Text(
              'Defense\n3.5',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
          Positioned(
            right: -12,
            bottom: 39,
            child: Text(
              'Net Play\n3.0',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
          Positioned(
            bottom: -1,
            child: Text(
              'Stamina\n3.5',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
          Positioned(
            left: -25,
            bottom: 39,
            child: Text(
              'Footwork\n4.0',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
          Positioned(
            left: -13,
            top: 48,
            child: Text(
              'Serve\n3.0',
              textAlign: TextAlign.center,
              style: _labelStyle(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillProgressRow extends StatelessWidget {
  const _SkillProgressRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final double value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 345,
      height: 24,
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(label, style: labelStyle)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    const ColoredBox(
                      color: Color(0xFFE1EEE9),
                      child: SizedBox.expand(),
                    ),
                    FractionallySizedBox(
                      widthFactor: value / 5,
                      alignment: Alignment.centerLeft,
                      child: const ColoredBox(
                        color: Color(0xFF087A61),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text(
              '${value.toStringAsFixed(1)} / 5',
              textAlign: TextAlign.right,
              style: valueStyle,
            ),
          ),
        ],
      ),
    );
  }
}
