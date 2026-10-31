import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/feedback_repository.dart';
import '../data/rating_api.dart';
import '../widgets/feedback_widgets.dart';
import 'rating_history_screen.dart';

class CommunityRatingScreen extends StatefulWidget {
  const CommunityRatingScreen({
    super.key,
    this.live = false,
    this.player = const FeedbackPlayer(
      'minh',
      'Minh',
      'assets/sprint8/feedback_minh.png',
    ),
  });
  final FeedbackPlayer player;
  final bool live;
  @override
  State<CommunityRatingScreen> createState() => _CommunityRatingScreenState();
}

class _CommunityRatingScreenState extends State<CommunityRatingScreen> {
  FeedbackPlayer get player => widget.player;
  RatingSummary? summary;
  List<TeammateFeedback> reviews = [];
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.live) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final id = int.parse(player.id);
      final api = RatingApi.current();
      final result = await api.summary(id);
      final rows = await api.ratings(given: false, targetId: id);
      final entries = rows
          .map(
            (r) => TeammateFeedback(
              player: FeedbackPlayer(
                '${r['rater']['id']}',
                r['rater']['fullName'] as String,
                '',
              ),
              stars: (r['score'] as num).toInt(),
              review: r['comment'] as String? ?? '',
              matchTitle: (r['match'] as Map?)?['title'] as String?,
              createdAt: DateTime.tryParse(r['createdAt'] as String? ?? ''),
            ),
          )
          .toList();
      if (mounted) {
        setState(() {
          summary = result;
          reviews = entries;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FeedbackScaffold(
    title: 'Community rating',
    subtitle: widget.live
        ? 'A reputation built together'
        : 'A reputation built together · UI preview',
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!, textAlign: TextAlign.center),
                TextButton(onPressed: load, child: const Text('Retry')),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              FeedbackCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FeedbackIdentity(
                      player: player,
                      subtitle: widget.live
                          ? 'Community rating'
                          : 'Intermediate · 12 matches',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.live ? summary?.label ?? '—' : '4.9',
                      style: feedbackText(
                        48,
                        weight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.live
                          ? '${summary?.count ?? 0} community ratings · Reliability ${summary?.reliability?.toStringAsFixed(2) ?? '—'}/5'
                          : '★★★★★  ·  32 community ratings',
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
                    for (final (star, count)
                        in widget.live
                            ? [
                                for (var i = 5; i >= 1; i--)
                                  (i, summary?.distribution[i] ?? 0),
                              ]
                            : [(5, 26), (4, 5), (3, 1), (2, 0), (1, 0)]) ...[
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
                                value: widget.live
                                    ? (summary?.count ?? 0) == 0
                                          ? 0
                                          : count / summary!.count
                                    : count / 32,
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
                              style: feedbackText(
                                12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!widget.live) ...[
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
              ],
              Text(
                'Recent reviews',
                style: feedbackText(18, weight: FontWeight.w600),
              ),
              if (widget.live) ...[
                if (reviews.isEmpty)
                  Text('No ratings yet', style: feedbackText(14)),
                for (final entry in reviews) ...[
                  const SizedBox(height: 16),
                  FeedbackReviewCard(entry: entry),
                ],
              ],
              if (!widget.live)
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
