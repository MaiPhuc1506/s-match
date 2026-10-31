import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../navigation/player_bottom_navigation.dart';
import '../data/feedback_repository.dart';

TextStyle feedbackText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.textPrimary,
  double line = 1.45,
}) => GoogleFonts.plusJakartaSans(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: line,
  letterSpacing: 0,
);

class FeedbackScaffold extends StatelessWidget {
  const FeedbackScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.navigation = true,
  });
  final String title, subtitle;
  final Widget child;
  final Widget? footer;
  final bool navigation;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: navigation
          ? PlayerBottomNavigation(
              currentTab: PlayerNavTab.feedback,
              allowCurrentTabNavigation: title != 'Rating history',
            )
          : null,
      body: SafeArea(
        bottom: !navigation,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 46,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: SvgPicture.asset(
                        'assets/icons/register_back.svg',
                        width: 19.2,
                        height: 19.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: feedbackText(20, weight: FontWeight.w600),
                        ),
                        Text(
                          subtitle,
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
            ),
            const SizedBox(height: 24),
            Expanded(child: child),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: footer!,
              ),
          ],
        ),
      ),
    ),
  );
}

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.child,
    this.padding = 20,
    this.onTap,
  });
  final Widget child;
  final double padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}

class FeedbackIdentity extends StatelessWidget {
  const FeedbackIdentity({
    super.key,
    required this.player,
    required this.subtitle,
    this.name,
  });
  final FeedbackPlayer player;
  final String subtitle;
  final String? name;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipOval(
        child: player.avatar.isEmpty
            ? Container(
                width: 44,
                height: 44,
                color: const Color(0xFFDDF1E9),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                ),
              )
            : Image.asset(
                player.avatar,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name ?? player.name,
              style: feedbackText(16, weight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: feedbackText(12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}

class FeedbackAction extends StatelessWidget {
  const FeedbackAction(
    this.label, {
    super.key,
    required this.onPressed,
    this.secondary = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: secondary ? Colors.white : AppColors.primary,
        foregroundColor: secondary ? AppColors.primaryDark : Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: .45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: secondary
              ? const BorderSide(color: AppColors.border)
              : BorderSide.none,
        ),
      ),
      child: loading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: feedbackText(
                      14,
                      weight: FontWeight.w600,
                      color: secondary ? AppColors.primaryDark : Colors.white,
                    ),
                  ),
                ),
                if (!secondary) ...[
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/icons/register_arrow.svg',
                    width: 16,
                    height: 16,
                  ),
                ],
              ],
            ),
    ),
  );
}

class FeedbackTag extends StatelessWidget {
  const FeedbackTag(this.label, {super.key, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: onTap != null,
    child: Material(
      color: selected ? AppColors.primary : const Color(0xFFF3F6F3),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(
            label,
            style: feedbackText(
              13,
              weight: FontWeight.w500,
              line: 18 / 13,
              color: selected ? Colors.white : const Color(0xFF142824),
            ),
          ),
        ),
      ),
    ),
  );
}

class FeedbackStars extends StatelessWidget {
  const FeedbackStars({super.key, required this.value, this.onChanged});
  final int value;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        SizedBox(
          width: onChanged == null ? (i == 5 ? 16 : 30) : 42,
          height: onChanged == null ? 16 : 44,
          child: onChanged == null
              ? Align(alignment: Alignment.topLeft, child: _star(i, 16))
              : Semantics(
                  label: '$i stars',
                  selected: value == i,
                  button: true,
                  child: IconButton(
                    tooltip: '$i stars',
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (!AppMotion.reduced(context)) {
                        HapticFeedback.selectionClick();
                      }
                      onChanged!(i);
                    },
                    icon: AnimatedSwitcher(
                      duration: AppMotion.duration(context, 160),
                      child: _star(i, 28),
                    ),
                  ),
                ),
        ),
    ],
  );

  Widget _star(int i, double size) => SizedBox.square(
    dimension: size,
    key: ValueKey('$i:${i <= value}'),
    child: Align(
      alignment: Alignment.topCenter,
      child: SvgPicture.asset(
        'assets/sprint8/rating_star.svg',
        width: size * .951057,
        height: size * .904507,
        colorFilter: i <= value
            ? null
            : const ColorFilter.mode(AppColors.border, BlendMode.srcIn),
      ),
    ),
  );
}

/// Exact 100px Figma instance geometry, exported as transparent child vectors.
class FeedbackSuccessBadge extends StatelessWidget {
  const FeedbackSuccessBadge({super.key, this.size = 100});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: FittedBox(
      child: SizedBox.square(
        dimension: 100,
        child: Stack(
          children: [
            Positioned(
              left: 4.166667,
              top: 4.166667,
              child: SvgPicture.asset(
                'assets/sprint8/success_circle.svg',
                width: 91.6667,
                height: 91.6667,
              ),
            ),
            Positioned(
              left: 27.166666,
              top: 31.333332,
              child: SvgPicture.asset(
                'assets/sprint8/success_tick.svg',
                width: 47.75,
                height: 35.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
