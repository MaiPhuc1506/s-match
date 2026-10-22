import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/sprint2_presentation.dart';
import '../widgets/profile_skill_radar.dart';

class SkillAssessmentScreen extends StatelessWidget {
  const SkillAssessmentScreen({super.key});

  TextStyle _style({
    required double size,
    required FontWeight weight,
    required double lineHeight,
    Color color = Sprint2Style.text,
  }) => Sprint2Style.font(size, lineHeight, weight: weight, color: color);

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: Sprint2Style.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 393),
          child: Column(
            children: [
              const Sprint2BackHeader(title: 'Skill Assessment'),
              Expanded(
                child: Sprint2FormBody(
                  spacing: 8,
                  button: _buildRetakeButton(),
                  children: [
                    _buildLevelCard(),
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F3EF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You’re improving!',
                            style: Sprint2Style.font(
                              13,
                              18,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep playing to develop your badminton skills.',
                            style: Sprint2Style.font(
                              12,
                              17,
                              color: Sprint2Style.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildRadarCard(),
                    _buildBreakdown(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildLevelCard() => Container(
    height: 128,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF05644F), Color(0xFF087A61)],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          left: 16,
          top: 16,
          child: Text(
            'Current Player Level',
            style: Sprint2Style.font(
              12,
              17,
              color: Colors.white,
            ).copyWith(letterSpacing: 1.44),
          ),
        ),
        Positioned(
          left: 16,
          top: 34,
          child: Text(
            'Intermediate',
            style: Sprint2Style.font(
              24,
              33,
              weight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 72,
          child: Text(
            'Level 3.4 • Solid foundation',
            style: Sprint2Style.font(12, 17, color: Colors.white),
          ),
        ),
        Positioned(
          right: 12,
          top: 29,
          child: Opacity(
            opacity: .65,
            child: Image.asset(
              'assets/images/skill_level_shuttle.png',
              width: 72,
              height: 72,
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 102,
          width: 220,
          height: 7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 150 / 220,
              backgroundColor: Color(0x2EFFFFFF),
              color: Color(0xFFC8EADD),
              minHeight: 7,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildRadarCard() => SizedBox(
    height: 264,
    child: Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          height: 32,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Skill Breakdown',
                  style: Sprint2Style.font(16, 22, weight: FontWeight.w600),
                ),
              ),
              // Presentation only: the current screen has no Chart / Details switching logic.
              Container(
                width: 142,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EFEB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    for (final label in ['Chart', 'Details'])
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: label == 'Chart'
                                ? Sprint2Style.primary
                                : Sprint2Style.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            label,
                            style: Sprint2Style.font(
                              12,
                              17,
                              weight: FontWeight.w500,
                              color: label == 'Chart'
                                  ? Colors.white
                                  : Sprint2Style.text,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const ProfileSkillRadar(assessment: true),
      ],
    ),
  );

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
      height: 174,
      child: Column(
        children: [
          for (var i = 0; i < skills.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(skills[i].$1, style: Sprint2Style.font(13, 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: skills[i].$2 / 5,
                        minHeight: 7,
                        color: Sprint2Style.primary,
                        backgroundColor: const Color(0xFFE2E7E5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${skills[i].$2.toStringAsFixed(1)} / 5',
                      textAlign: TextAlign.right,
                      style: Sprint2Style.font(
                        13,
                        18,
                        color: Sprint2Style.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
          backgroundColor: const Color(0xFFE2EEE8),
          foregroundColor: Sprint2Style.primary,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Sprint2Style.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Retake Assessment',
              style: _style(
                size: 14,
                weight: FontWeight.w500,
                lineHeight: 20,
                color: Sprint2Style.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
