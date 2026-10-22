import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/primary_button.dart';
import '../widgets/recommendation_widgets.dart';

class NoRecommendationsScreen extends StatelessWidget {
  const NoRecommendationsScreen({super.key, this.onSearchAgain});
  final VoidCallback? onSearchAgain;
  @override
  Widget build(BuildContext context) => RecommendationScaffold(
    child: Stack(
      children: [
        SingleChildScrollView(
          key: const PageStorageKey('no_recommendations_scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(36, 58, 36, 10),
          child: Column(
            children: [
              SvgPicture.asset(
                '${recommendationAssets}no_recommendations.svg',
                width: 260,
                height: 208,
              ),
              const SizedBox(height: 20),
              Text(
                'No matching players\nright now',
                textAlign: TextAlign.center,
                style: recommendationText(
                  22,
                  weight: FontWeight.w700,
                  line: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'We couldn’t find players that match your current preferences. Try adjusting your criteria to get more results.',
                textAlign: TextAlign.center,
                style: recommendationText(
                  13,
                  color: AppColors.textSecondary,
                  line: 19,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'Search Again',
                showArrow: false,
                onPressed: onSearchAgain ?? () => recommendationBack(context),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.socialPressed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Some suggestions',
                      style: recommendationText(14, weight: FontWeight.w600),
                    ),
                    for (final text in const [
                      'Increase the search radius',
                      'Try a different skill level',
                      'Adjust your available time',
                      'Keep your preferences flexible',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CompatibilityReason(text),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Positioned(left: 12, top: 4, child: RecommendationBackButton()),
      ],
    ),
  );
}
