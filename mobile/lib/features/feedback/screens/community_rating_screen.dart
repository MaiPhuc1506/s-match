import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/feedback_repository.dart';
import '../widgets/feedback_widgets.dart';
import 'rating_history_screen.dart';

class CommunityRatingScreen extends StatelessWidget {
  const CommunityRatingScreen({
    super.key,
    this.player = const FeedbackPlayer(
      'minh',
      'Minh',
      'assets/sprint8/feedback_minh.png',
    ),
  });
  final FeedbackPlayer player;
  @override
  Widget build(BuildContext context) => FeedbackScaffold(
    title: 'Community rating',
    subtitle: 'A reputation built together · UI preview',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        FeedbackCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeedbackIdentity(
                player: player,
                subtitle: 'Intermediate · 12 matches',
              ),
              const SizedBox(height: 10),
              Text(
                '4.9',
                style: feedbackText(
                  48,
                  weight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '★★★★★  ·  32 community ratings',
                style: feedbackText(
                  13,
                  weight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FeedbackCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rating breakdown',
                style: feedbackText(18, weight: FontWeight.w600),
              ),
              for (final (star, count) in [
                (5, 26),
                (4, 5),
                (3, 1),
                (2, 0),
                (1, 0),
              ]) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      child: Text(
                        '$star',
                        style: feedbackText(
                          12,
                          weight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        label: '$star stars: $count ratings',
                        child: LinearProgressIndicator(
                          value: count / 32,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(4),
                          color: AppColors.primary,
                          backgroundColor: const Color(0xFFEEF7F3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '$count',
                        style: feedbackText(12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Players appreciate',
          style: feedbackText(18, weight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FeedbackTag('Teamwork · 24', selected: true),
            FeedbackTag('Fair play · 21', selected: true),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Recent reviews',
          style: feedbackText(18, weight: FontWeight.w600),
        ),
        for (final teammate in feedbackTeammates.where(
          (p) => p.id != player.id,
        )) ...[
          const SizedBox(height: 16),
          FeedbackReviewCard(
            entry: TeammateFeedback(
              player: teammate,
              stars: 5,
              review: 'Great sportsmanship and a reliable teammate. See you at the next rally!',
            ),
            subtitle: 'Verified match · 31 Oct',
          ),
        ],
      ],
    ),
  );
}
