import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../match/screens/match_list_screen.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../data/feedback_repository.dart';
import '../widgets/feedback_widgets.dart';
import 'community_rating_screen.dart';

class RatingHistoryScreen extends StatefulWidget {
  const RatingHistoryScreen({
    super.key,
    this.repository,
    this.initiallyGiven = false,
  });
  final FeedbackRepository? repository;
  final bool initiallyGiven;
  @override
  State<RatingHistoryScreen> createState() => _RatingHistoryScreenState();
}

class _RatingHistoryScreenState extends State<RatingHistoryScreen> {
  FeedbackRepository get repo =>
      widget.repository ?? FeedbackRepository.instance;
  late bool given = widget.initiallyGiven;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repo,
    builder: (context, _) {
      final entries = given ? repo.given : repo.received;
      return FeedbackScaffold(
        title: 'Rating history',
        subtitle: 'Your growth, one match at a time · UI preview',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR REPUTATION',
                    style: feedbackText(
                      11,
                      weight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          repo.withSamples ? '4.8' : '—',
                          style: feedbackText(
                            48,
                            weight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.withSamples
                                  ? 'Excellent teammate'
                                  : 'No ratings yet',
                              style: feedbackText(
                                16,
                                weight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Text(
                              repo.withSamples
                                  ? '24 ratings · 12 matches'
                                  : '0 ratings · 0 matches',
                              style: feedbackText(
                                12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (repo.withSamples) ...[
                    const SizedBox(height: 8),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FeedbackTag('Team player', selected: true),
                        FeedbackTag('Fair play', selected: true),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final option in [false, true]) ...[
                  if (option) const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FeedbackTag(
                        option ? 'Given' : 'Received',
                        selected: given == option,
                        onTap: () => setState(() => given = option),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: AppMotion.duration(context, 250),
              child: entries.isEmpty
                  ? Column(
                      key: ValueKey('empty-$given'),
                      children: [
                        FeedbackCard(
                          padding: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FeedbackSuccessBadge(size: 56),
                              const SizedBox(height: 16),
                              Text(
                                'Your story starts on court',
                                style: feedbackText(
                                  21,
                                  weight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                given
                                    ? 'Rate your teammates after a completed match. Your shared feedback will appear here.'
                                    : 'Play a match and exchange feedback. Your received ratings will appear here.',
                                style: feedbackText(
                                  14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FeedbackAction(
                          'Find Your Next Match',
                          onPressed: () => PlayerBottomNavigation.navigateTo(
                            context,
                            const MatchListScreen(),
                            routeName: '/player-match',
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: ValueKey('entries-$given'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          given
                              ? 'Feedback you’ve shared'
                              : 'What teammates say',
                          style: feedbackText(17, weight: FontWeight.w600),
                        ),
                        for (final entry in entries) ...[
                          const SizedBox(height: 16),
                          FeedbackReviewCard(
                            entry: entry,
                            given: given,
                            onTap: () => Navigator.of(context).push(
                              AppMotion.route(
                                CommunityRatingScreen(player: entry.player),
                                name: '/community-rating',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class FeedbackReviewCard extends StatelessWidget {
  const FeedbackReviewCard({
    super.key,
    required this.entry,
    this.given = false,
    this.onTap,
    this.subtitle = 'Saturday Rally · 31 Oct',
  });
  final TeammateFeedback entry;
  final bool given;
  final VoidCallback? onTap;
  final String subtitle;
  @override
  Widget build(BuildContext context) => FeedbackCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedbackIdentity(
          player: entry.player,
          name: given ? 'To ${entry.player.name}' : entry.player.name,
          subtitle: subtitle,
        ),
        const SizedBox(height: 10),
        FeedbackStars(value: entry.stars),
        if (entry.review.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(entry.review, style: feedbackText(14)),
        ],
      ],
    ),
  );
}
