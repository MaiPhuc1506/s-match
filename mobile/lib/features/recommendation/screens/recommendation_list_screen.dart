import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../court_map/widgets/exploration_widgets.dart';
import '../data/recommendation_repository.dart';
import '../models/recommended_player.dart';
import '../widgets/recommendation_widgets.dart';
import 'no_recommendations_screen.dart';
import 'recommended_player_detail_screen.dart';

class RecommendationListScreen extends ConsumerWidget {
  const RecommendationListScreen({
    super.key,
    this.query = const RecommendationQuery(),
    this.onSearchAgain,
  });
  final RecommendationQuery query;
  final VoidCallback? onSearchAgain;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void searchAgain() {
      if (onSearchAgain != null) {
        onSearchAgain!();
        return;
      }
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        recommendationBack(context);
      }
    }

    final results = ref.watch(recommendationsProvider(query));
    final preview = ref.watch(recommendationRepositoryProvider).isPreview;
    if (!results.isLoading &&
        !results.hasError &&
        results.hasValue &&
        results.requireValue.isEmpty) {
      return NoRecommendationsScreen(onSearchAgain: searchAgain);
    }
    return RecommendationScaffold(
      action: searchAgain,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const RecommendationBackButton(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended Players',
                        style: recommendationText(
                          18,
                          weight: FontWeight.w600,
                          line: 24,
                        ),
                      ),
                      Text(
                        preview
                            ? 'UI preview · Based on your preferences'
                            : 'Based on your preferences',
                        style: recommendationText(
                          12,
                          color: AppColors.textSecondary,
                          line: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (error, _) => Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is RecommendationFailure ? error.message : 'Unable to load recommendations. Please try again.',
                        textAlign: TextAlign.center,
                        style: recommendationText(14),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(recommendationsProvider(query)),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (players) => Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.socialPressed,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${players.length}',
                          style: recommendationText(
                            42,
                            weight: FontWeight.w700,
                            color: AppColors.iconPrimary,
                            line: 61,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'players match your preferences',
                                style: recommendationText(
                                  14,
                                  weight: FontWeight.w600,
                                  color: AppColors.iconPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on skill, availability and distance',
                                style: recommendationText(
                                  11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      key: const PageStorageKey('recommendations_scroll'),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: players.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => RecommendationCard(
                        player: players[i],
                        onTap: () => Navigator.of(context).push(
                          explorationRoute<void>(
                            RecommendedPlayerDetailScreen(player: players[i]),
                            '/recommended-player',
                          ),
                        ),
                      ),
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
}
