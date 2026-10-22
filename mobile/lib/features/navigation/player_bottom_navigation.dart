import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/court_map/screens/find_courts_map_screen.dart';
import 'package:mobile/features/match/screens/match_list_screen.dart';
import 'package:mobile/features/auth/screens/player_profile_screen.dart';

/// Five primary tabs for Player navigation in S-Match:
/// Home / Map / Match / Feedback / Profile
enum PlayerNavTab { home, map, match, feedback, profile }

/// Unified Player bottom navigation component matching S-Match visual specifications.
///
/// Reference specifications:
/// - Reference frame: 393 × 852
/// - Reference height: 84
/// - Reference padding: top 8, right 12, bottom 22, left 12
/// - Five equally distributed items (reference size: 64 × 48)
/// - Icon size: 22 × 22, gap: 4
/// - Font: Plus Jakarta Sans, Medium 500, size 11, line-height 15
/// - Colors: Selected #05644F, Inactive #7A8985
/// - Background: Pure white, no decorative borders or shadows
class PlayerBottomNavigation extends StatelessWidget {
  final PlayerNavTab? currentTab;
  final ValueChanged<PlayerNavTab>? onTapTab;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateMap;
  final VoidCallback? onNavigateMatch;
  final VoidCallback? onNavigateFeedback;
  final VoidCallback? onNavigateProfile;
  final bool allowCurrentTabNavigation;

  const PlayerBottomNavigation({
    super.key,
    required this.currentTab,
    this.onTapTab,
    this.onNavigateHome,
    this.onNavigateMap,
    this.onNavigateMatch,
    this.onNavigateFeedback,
    this.onNavigateProfile,
    this.allowCurrentTabNavigation = false,
  });

  static const Color _selectedColor = Color(0xFF05644F);
  static const Color _inactiveColor = Color(0xFF7A8985);

  /// Includes the device inset once; callers must not wrap the bar in SafeArea.
  static double heightFor(BuildContext context) =>
      84 + math.max(0, MediaQuery.viewPaddingOf(context).bottom - 22);

  static (String asset, String label) _tabData(PlayerNavTab tab) {
    switch (tab) {
      case PlayerNavTab.home:
        return ('assets/sprint6/find_courts/nav_home.svg', 'Home');
      case PlayerNavTab.map:
        return ('assets/sprint6/find_courts/nav_map.svg', 'Map');
      case PlayerNavTab.match:
        return ('assets/sprint6/find_courts/nav_match.svg', 'Match');
      case PlayerNavTab.feedback:
        return ('assets/sprint6/find_courts/nav_feedback.svg', 'Feedback');
      case PlayerNavTab.profile:
        return ('assets/sprint6/find_courts/nav_profile.svg', 'Profile');
    }
  }

  /// Smooth dissolve route transition between top-level Player tabs.
  /// Uses pushReplacement to prevent accumulating duplicate screens in the stack.
  static void navigateTo(
    BuildContext context,
    Widget destination, {
    required String routeName,
  }) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: routeName),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  /// Informs the user when a destination tab is not yet implemented in the app.
  static void showFeatureNotice(BuildContext context, String featureName) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$featureName hiện đang được phát triển'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleTap(BuildContext context, PlayerNavTab tab) {
    // Nested flows may opt in to returning to their selected top-level tab.
    if (tab == currentTab && !allowCurrentTabNavigation) {
      return;
    }

    if (onTapTab != null) {
      onTapTab!(tab);
      return;
    }

    switch (tab) {
      case PlayerNavTab.home:
        if (onNavigateHome != null) {
          onNavigateHome!();
        } else {
          showFeatureNotice(context, 'Trang chủ (Home)');
        }
        break;

      case PlayerNavTab.map:
        if (onNavigateMap != null) {
          onNavigateMap!();
        } else {
          navigateTo(
            context,
            const FindCourtsMapScreen(),
            routeName: '/player-map',
          );
        }
        break;

      case PlayerNavTab.match:
        if (onNavigateMatch != null) {
          onNavigateMatch!();
        } else {
          navigateTo(
            context,
            const MatchListScreen(),
            routeName: '/player-match',
          );
        }
        break;

      case PlayerNavTab.feedback:
        if (onNavigateFeedback != null) {
          onNavigateFeedback!();
        } else {
          showFeatureNotice(context, 'Phản hồi (Feedback)');
        }
        break;

      case PlayerNavTab.profile:
        if (onNavigateProfile != null) {
          onNavigateProfile!();
        } else {
          navigateTo(
            context,
            const PlayerProfileScreen(),
            routeName: '/player-profile',
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // In Figma reference (393 × 852), bottom padding is 22px (which includes the home indicator).
    // On devices with real safe-area bottom insets (e.g. 34px), use max(22.0, bottomInset)
    // so we respect the device safe area without adding 22 on top of the inset.
    final bottomPadding = math.max(22.0, bottomInset);
    final totalHeight = heightFor(context);

    return Container(
      width: double.infinity,
      height: totalHeight,
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: PlayerNavTab.values.map((tab) {
          final isSelected = tab == currentTab;
          final color = isSelected ? _selectedColor : _inactiveColor;
          final (asset, label) = _tabData(tab);

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _handleTap(context, tab),
              child: Center(
                child: SizedBox(
                  width: 64,
                  height: 48,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: SvgPicture.asset(
                          asset,
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 15 / 11,
                            color: color,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
