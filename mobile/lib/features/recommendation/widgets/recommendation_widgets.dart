import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/primary_button.dart';
import '../../court_map/screens/find_players_map_screen.dart';
import '../../court_map/widgets/exploration_widgets.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../models/recommended_player.dart';

const recommendationAssets = 'assets/sprint7/recommendation/';

TextStyle recommendationText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.textPrimary,
  double? line,
}) => exploreText(size, weight: weight, color: color, line: line);

void recommendationBack(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    PlayerBottomNavigation.navigateTo(
      context,
      const FindPlayersMapScreen(),
      routeName: '/find-players',
    );
  }
}

class RecommendationScaffold extends StatelessWidget {
  const RecommendationScaffold({
    super.key,
    required this.child,
    this.action,
    this.actionLabel = 'Search Again',
  });
  final Widget child;
  final VoidCallback? action;
  final String actionLabel;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SizedBox(height: math.max(52, MediaQuery.paddingOf(context).top)),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: PrimaryButton(
                  text: actionLabel,
                  onPressed: action!,
                  showArrow: false,
                ),
              ),
            ),
          const PlayerBottomNavigation(
            currentTab: PlayerNavTab.map,
            allowCurrentTabNavigation: true,
          ),
        ],
      ),
    ),
  );
}

class RecommendationBackButton extends StatelessWidget {
  const RecommendationBackButton({super.key, this.onBack, this.filled = false});
  final VoidCallback? onBack;
  final bool filled;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onBack ?? () => recommendationBack(context),
    style: IconButton.styleFrom(
      backgroundColor: filled ? Colors.white : Colors.transparent,
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
    ),
    icon: SvgPicture.asset(
      'assets/icons/back_chevron.svg',
      width: 24,
      height: 24,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.chevron_left, color: AppColors.primary, size: 24),
    ),
  );
}

class RecommendationAvatar extends StatelessWidget {
  const RecommendationAvatar(this.player, {super.key, this.size = 56});
  final RecommendedPlayer player;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.socialPressed,
      child: Center(
        child: Icon(
          Icons.person_outline,
          color: AppColors.primary,
          size: size * .5,
        ),
      ),
    );
    final Widget image;
    if (player.avatarAsset != null) {
      image = Image.asset(
        player.avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (player.avatarUrl != null) {
      image = Image.network(
        player.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }
    return SizedBox.square(
      dimension: size,
      child: ClipOval(child: image),
    );
  }
}

class CompatibilityScore extends StatelessWidget {
  const CompatibilityScore(this.score, {super.key, this.large = false});
  final double score;
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Compatibility ${score.toStringAsFixed(0)} percent',
    child: SizedBox.square(
      dimension: large ? 80 : 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: large ? 5 : 3,
              strokeAlign: -1,
              backgroundColor: AppColors.socialPressed,
              color: AppColors.primary,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.toStringAsFixed(0)}%',
                    maxLines: 1,
                    softWrap: false,
                    style: recommendationText(
                      large ? 22 : 14,
                      weight: FontWeight.w700,
                      color: AppColors.iconPrimary,
                    ),
                  ),
                  if (large)
                    Text(
                      'Match',
                      style: recommendationText(
                        11,
                        color: AppColors.iconPrimary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CompatibilityReason extends StatelessWidget {
  const CompatibilityReason(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            '${recommendationAssets}reason_check.svg',
            width: 12,
            height: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: recommendationText(12, line: 17))),
      ],
    ),
  );
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.player,
    required this.onTap,
  });
  final RecommendedPlayer player;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 164),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.socialPressed),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RecommendationAvatar(player),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.displayName,
                          style: recommendationText(
                            14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (player.level != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.socialPressed,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  player.level!,
                                  style: recommendationText(
                                    10,
                                    weight: FontWeight.w500,
                                    color: AppColors.iconPrimary,
                                  ),
                                ),
                              ),
                            if (player.distanceKm != null)
                              Text(
                                '${player.distanceKm!.toStringAsFixed(1)} km',
                                style: recommendationText(
                                  10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompatibilityScore(player.score),
                ],
              ),
              const SizedBox(height: 6),
              if (player.reasons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Compatibility reasons are not available yet.',
                    style: recommendationText(
                      12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final (index, reason) in player.reasons.take(3).indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
                  child: CompatibilityReason(reason),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
