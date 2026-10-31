import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../data/feedback_repository.dart';
import '../data/rating_api.dart';
import '../widgets/feedback_widgets.dart';
import 'rating_history_screen.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({
    super.key,
    this.repository,
    this.matchId = 'preview_saturday',
    this.match,
  });
  final FeedbackRepository? repository;
  final String matchId;
  final FeedbackMatch? match;
  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  FeedbackRepository get repo =>
      widget.repository ?? FeedbackRepository.instance;
  List<FeedbackPlayer> get players =>
      widget.match?.players ?? feedbackTeammates;
  late final _stars = List.filled(players.length, 0);
  late final _tags = List.generate(players.length, (_) => <String>{});
  late final _reviews = List.generate(
    players.length,
    (_) => TextEditingController(),
  );
  bool _sending = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _reviews) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_stars.contains(0)) {
      setState(
        () => _error =
            'Please rate all ${players.length} teammates before submitting.',
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await repo.submit(
        widget.matchId,
        List.generate(
          players.length,
          (i) => TeammateFeedback(
            player: players[i],
            stars: _stars[i],
            tags: _tags[i],
            review: _reviews[i].text,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppMotion.route(
          FeedbackSubmittedScreen(
            repository: repo,
            names: players.map((p) => p.name).join(', '),
          ),
          name: '/feedback-submitted',
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error is RatingFailure
              ? error.message
              : error is StateError
              ? error.message
              : 'Some ratings may have saved. Retry to send only the remaining teammates.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FeedbackScaffold(
    title: 'Rate your teammates',
    subtitle: widget.match == null
        ? 'Saturday Rally · 3 teammates · UI preview'
        : '${widget.match!.title} · ${players.length} teammates',
    navigation: false,
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: feedbackText(12, color: const Color(0xFF914A45)),
              ),
            ),
          ),
        FeedbackAction(
          'Submit Feedback',
          onPressed: _submit,
          loading: _sending,
        ),
        const SizedBox(height: 6),
        Text(
          'Be kind. Be specific. Help each other grow.',
          textAlign: TextAlign.center,
          style: feedbackText(11, color: AppColors.textSecondary),
        ),
      ],
    ),
    child: AbsorbPointer(
      absorbing: _sending,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'How was the match?',
            style: feedbackText(
              24,
              weight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'A little feedback makes the next rally better.',
            style: feedbackText(14, color: AppColors.textSecondary),
          ),
          for (var i = 0; i < players.length; i++) ...[
            const SizedBox(height: 16),
            FeedbackCard(
              key: ValueKey('feedback-card-$i'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeedbackIdentity(
                    player: players[i],
                    subtitle: 'Your doubles community',
                  ),
                  const SizedBox(height: 8),
                  FeedbackStars(
                    value: _stars[i],
                    onChanged: (v) => setState(() => _stars[i] = v),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag
                          in repo.live
                              ? <String>[]
                              : ['Great teamwork', 'Fair play'])
                        FeedbackTag(
                          tag,
                          selected: _tags[i].contains(tag),
                          onTap: () {
                            if (!AppMotion.reduced(context)) {
                              HapticFeedback.selectionClick();
                            }
                            setState(() {
                              if (!_tags[i].add(tag)) _tags[i].remove(tag);
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Review (optional)',
                    style: feedbackText(12, weight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: ValueKey('feedback-review-$i'),
                    controller: _reviews[i],
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    style: feedbackText(14, line: 20 / 14),
                    decoration: InputDecoration(
                      hintText: 'Share something helpful…',
                      counterStyle: feedbackText(
                        12,
                        color: AppColors.textSecondary,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class FeedbackSubmittedScreen extends StatelessWidget {
  const FeedbackSubmittedScreen({
    super.key,
    this.repository,
    this.names = 'Minh, An and Huy',
  });
  final String names;
  final FeedbackRepository? repository;
  @override
  Widget build(BuildContext context) => FeedbackScaffold(
    title: 'Feedback sent',
    subtitle: repository?.live == true
        ? 'Thanks for supporting your teammates'
        : 'Thanks for supporting your teammates · UI preview',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 24),
      children: [
        Center(child: FeedbackSuccessBadge(size: 96)),
        const SizedBox(height: 20),
        Text(
          'Good teammates\nmake great matches.',
          textAlign: TextAlign.center,
          style: feedbackText(
            27,
            weight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Your feedback for $names has been submitted. Keep the good rallies going.',
          textAlign: TextAlign.center,
          style: feedbackText(14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        FeedbackAction(
          'View Rating History',
          onPressed: () => Navigator.of(context).pushReplacement(
            AppMotion.route(
              RatingHistoryScreen(repository: repository, initiallyGiven: true),
              name: '/rating-history',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FeedbackAction(
          'Back to Match',
          secondary: true,
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
    ),
  );
}
