import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/profile_skill_radar.dart';
import '../../court_map/widgets/exploration_widgets.dart';
import '../../match/screens/match_list_screen.dart';
import '../models/recommended_player.dart';
import '../widgets/recommendation_widgets.dart';

class RecommendedPlayerDetailScreen extends StatelessWidget {
  const RecommendedPlayerDetailScreen({super.key, required this.player});
  final RecommendedPlayer player;

  Future<void> _invite(BuildContext context) async {
    // Sprint 5 currently invites fixed demo email contacts, not recommended IDs.
    // Do not imply that a real invitation to this player has been sent.
    final chooseMatch = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite to Match'),
        content: const Text(
          'Open Match Organization to manage your matches. Inviting this recommended player directly is not supported yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open Matches'),
          ),
        ],
      ),
    );
    if (chooseMatch == true && context.mounted) {
      Navigator.of(
        context,
      ).push(explorationRoute<void>(const MatchListScreen(), '/player-match'));
    }
  }

  @override
  Widget build(BuildContext context) => RecommendationScaffold(
    actionLabel: 'Invite to Match',
    action: () => _invite(context),
    child: Stack(
      children: [
        SingleChildScrollView(
          key: const PageStorageKey('recommended_player_scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            children: [
              _hero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compatibility',
                                style: recommendationText(
                                  18,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Based on your preferences',
                                style: recommendationText(
                                  11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        CompatibilityScore(player.score, large: true),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Why you're a match",
                      style: recommendationText(16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.socialPressed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (player.reasons.isEmpty)
                            Text(
                              'Compatibility reasons are not available yet.',
                              style: recommendationText(
                                12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          for (final (index, reason) in _detailReasons.indexed)
                            Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : 10,
                              ),
                              child: CompatibilityReason(reason),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _stats(),
                    const SizedBox(height: 16),
                    Text(
                      'Skill Overview',
                      style: recommendationText(16, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (player.hasReferenceRadar)
                      const Center(child: ProfileSkillRadar(refined: true))
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Skill breakdown is not available yet.',
                          style: recommendationText(
                            12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _playingStyle(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Available time',
                            style: recommendationText(
                              12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            player.availability ?? 'Not available yet',
                            textAlign: TextAlign.right,
                            style: recommendationText(
                              12,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 12,
          top: 8,
          child: RecommendationBackButton(filled: true),
        ),
      ],
    ),
  );

  List<String> get _detailReasons =>
      player.hasReferenceRadar && player.id == 'reference-0'
      ? const [
          'Similar skill level (Intermediate)',
          'Available at your preferred time',
          'Lives nearby (1.2 km)',
          'Similar play style (Defensive)',
          'High compatibility for doubles',
        ]
      : player.reasons;

  Widget _hero() => LayoutBuilder(
    builder: (_, constraints) => Stack(
      children: [
        SizedBox(
          height: 270,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 242,
                child: ClipRect(
                  child: OverflowBox(
                    maxHeight: 356,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/images/match/facility_court.jpg',
                      width: constraints.maxWidth,
                      height: 356,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const Positioned(
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
                  '${recommendationAssets}profile_curve.svg',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: constraints.maxWidth - 119,
                top: 118,
                child: Opacity(
                  opacity: .7,
                  child: Image.asset(
                    'assets/images/skill_level_shuttle.png',
                    width: 88,
                    height: 88,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 136, 24, 0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: RecommendationAvatar(player, size: 100),
                ),
                const SizedBox(height: 4),
                Text(
                  player.displayName,
                  textAlign: TextAlign.center,
                  style: recommendationText(
                    22,
                    line: 30,
                    weight: FontWeight.w700,
                    color: const Color(0xFF142824),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (player.level != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.roleSelectedCard,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/profile_level_racket.svg',
                              width: 18,
                              height: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              player.level!,
                              style: recommendationText(
                                12,
                                weight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (player.rating != null)
                      Text(
                        '★ ${player.rating} (${player.matches})',
                        style: recommendationText(
                          14,
                          weight: FontWeight.w500,
                          color: const Color(0xFFF5B72F),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (player.location != null || player.distanceKm != null)
                  Text(
                    [
                      if (player.location != null) '● ${player.location}',
                      if (player.distanceKm != null)
                        '${player.distanceKm!.toStringAsFixed(1)} km away',
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: recommendationText(
                      12,
                      color: const Color(0xFF64716D),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  player.bio ?? 'Player biography is not available yet.',
                  textAlign: TextAlign.center,
                  style: recommendationText(
                    12,
                    line: 17,
                    color: const Color(0xFF64716D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stats() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final (i, stat) in [
            (player.matches?.toString() ?? '—', 'Matches', Icons.sports_tennis),
            (player.completed?.toString() ?? '—', 'Completed', Icons.check),
            (player.rating?.toString() ?? '—', 'Rating', Icons.star),
          ].indexed) ...[
            if (i > 0)
              const VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i < 2)
                    SvgPicture.asset(
                      i == 0
                          ? 'assets/icons/profile_level_racket.svg'
                          : 'assets/icons/sprint5_check.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primary,
                        BlendMode.srcIn,
                      ),
                    )
                  else
                    Text(
                      '★',
                      style: recommendationText(
                        14,
                        line: 14,
                        color: const Color(0xFFF5B72F),
                      ),
                    ),
                  Text(
                    stat.$1,
                    style: recommendationText(
                      20,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    stat.$2,
                    style: recommendationText(
                      10,
                      color: AppColors.textSecondary,
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

  Widget _playingStyle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    constraints: const BoxConstraints(minHeight: 80),
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F3EF),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 68.2,
            maxWidth: 68.2,
            minHeight: 68.2,
            maxHeight: 68.2,
            child: Image.asset(
              'assets/images/profile_playing_style_racket.png',
              width: 68.2,
              height: 68.2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Playing Style',
                style: recommendationText(16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (player.mode == null && player.playStyle == null)
                Text('Not available yet', style: recommendationText(12))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (player.mode != null) _chip(player.mode!, true),
                    if (player.playStyle != null)
                      _chip(player.playStyle!, false),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, bool selected) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? AppColors.primary : const Color(0xFFF6DEDC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: recommendationText(
        12,
        weight: FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF924A45),
      ),
    ),
  );
}
