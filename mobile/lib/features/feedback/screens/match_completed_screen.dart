import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../data/feedback_repository.dart';
import '../widgets/feedback_widgets.dart';
import 'feedback_form_screen.dart';
import 'rating_history_screen.dart';

/// Figma Celebration Clean. This sample does not mark any backend match complete.
class MatchCompletedScreen extends StatefulWidget {
  const MatchCompletedScreen({super.key, this.repository});
  final FeedbackRepository? repository;
  @override
  State<MatchCompletedScreen> createState() => _MatchCompletedScreenState();
}

class _MatchCompletedScreenState extends State<MatchCompletedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _started = false;
  FeedbackRepository get repo =>
      widget.repository ?? FeedbackRepository.instance;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
        HapticFeedback.lightImpact();
      }
    } else if (AppMotion.reduced(context)) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _entrance(Widget child, {int delay = 0}) {
    if (AppMotion.reduced(context)) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 150),
        builder: (_, value, child) => Opacity(opacity: value, child: child),
        child: child,
      );
    }
    final anim = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay / 900, (delay + 240) / 900, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: anim,
      child: AnimatedBuilder(
        animation: anim,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - anim.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 296,
                    child: Opacity(
                      opacity: .55,
                      child: SvgPicture.asset(
                        'assets/sprint8/mint_wave.svg',
                        height: 118,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(
                        height: 246,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            width: 290,
                            height: 190,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SvgPicture.asset(
                                  'assets/sprint8/celebration_halo.svg',
                                  width: 164,
                                  height: 164,
                                ),
                                if (!AppMotion.reduced(context))
                                  AnimatedBuilder(
                                    animation: _controller,
                                    builder: (_, child) => Opacity(
                                      opacity: (1 - _controller.value).clamp(
                                        0,
                                        1,
                                      ),
                                      child: Transform.translate(
                                        offset: Offset(
                                          0,
                                          _controller.value * 24,
                                        ),
                                        child: child,
                                      ),
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/sprint8/celebration_confetti.svg',
                                      width: 232,
                                      height: 96,
                                    ),
                                  ),
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (_, child) {
                                    final progress =
                                        (_controller.value * 900 / 420).clamp(
                                          0.0,
                                          1.0,
                                        );
                                    return Transform.scale(
                                      scale: AppMotion.reduced(context)
                                          ? 1
                                          : .82 +
                                                .18 *
                                                    Curves.easeOutBack
                                                        .transform(progress),
                                      child: Opacity(
                                        opacity: AppMotion.reduced(context)
                                            ? 1
                                            : progress,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Semantics(
                                    label: 'Match completed successfully',
                                    child: FeedbackSuccessBadge(size: 100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _entrance(
                        Column(
                          children: [
                            Text(
                              'Match Complete!',
                              textAlign: TextAlign.center,
                              style: feedbackText(
                                30,
                                weight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Great rallies. Even better teammates.',
                              textAlign: TextAlign.center,
                              style: feedbackText(
                                14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 70),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: Column(
                          children: [
                            _entrance(
                              FeedbackCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COMPLETED · DOUBLES',
                                      style: feedbackText(
                                        11,
                                        weight: FontWeight.w600,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Saturday Rally',
                                      style: feedbackText(
                                        22,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sat, 31 Oct · 18:00–20:00',
                                      style: feedbackText(
                                        13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Viet Badminton · Court 03',
                                      style: feedbackText(
                                        13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        for (var i = 0; i < 4; i++)
                                          Expanded(
                                            child: Column(
                                              children: [
                                                i == 0
                                                    ? SvgPicture.asset(
                                                        'assets/sprint8/you_avatar.svg',
                                                        width: 44,
                                                        height: 44,
                                                      )
                                                    : ClipOval(
                                                        child: Image.asset(
                                                          feedbackTeammates[i -
                                                                  1]
                                                              .avatar,
                                                          width: 44,
                                                          height: 44,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  i == 0
                                                      ? 'You'
                                                      : feedbackTeammates[i - 1]
                                                            .name,
                                                  style: feedbackText(12),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              delay: 60,
                            ),
                            const SizedBox(height: 18),
                            ListenableBuilder(
                              listenable: repo,
                              builder: (context, _) => FeedbackAction(
                                repo.submitted('preview_saturday')
                                    ? 'View Rating History'
                                    : 'Rate Your Teammates',
                                onPressed: () => Navigator.of(context).push(
                                  AppMotion.route(
                                    repo.submitted('preview_saturday')
                                        ? RatingHistoryScreen(
                                            repository: repo,
                                            initiallyGiven: true,
                                          )
                                        : FeedbackFormScreen(repository: repo),
                                    name: '/feedback-form',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            FeedbackAction(
                              'View Rating History',
                              secondary: true,
                              onPressed: () => Navigator.of(context).push(
                                AppMotion.route(
                                  RatingHistoryScreen(repository: repo),
                                  name: '/rating-history',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'UI preview · Sample match · Not saved to server',
                          style: feedbackText(
                            10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
