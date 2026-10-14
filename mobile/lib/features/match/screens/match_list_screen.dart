import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_model.dart';
import '../state/match_ui_store.dart';
import 'match_invitations_screen.dart';
import '../widgets/match_card.dart';
import 'create_match_screen.dart';
import 'match_detail_open_screen.dart';
import 'package:mobile/features/navigation/player_bottom_navigation.dart';

/// Screen 01: Match List (Figma Node 413:884)
/// Reference viewport: 393 × 852, Background: #F7F8F5
class MatchListScreen extends StatefulWidget {
  final VoidCallback? onCreateMatch;
  final VoidCallback? onMyMatches;
  final ValueChanged<MatchItem>? onMatchDetail;
  final VoidCallback? onNavigateHome;
  final VoidCallback? onNavigateMap;
  final VoidCallback? onNavigateFeedback;
  final VoidCallback? onNavigateProfile;

  const MatchListScreen({
    super.key,
    this.onCreateMatch,
    this.onMyMatches,
    this.onMatchDetail,
    this.onNavigateHome,
    this.onNavigateMap,
    this.onNavigateFeedback,
    this.onNavigateProfile,
  });

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  int _selectedTabIndex = 0; // 0: Open Matches, 1: My Matches
  int _selectedFilterIndex = 0; // 0: Today, 1: This week, 2: Filter
  String? _level;

  List<MatchItem> get _visible => MatchUiStore.instance.visible(
    mine: _selectedTabIndex == 1,
    todayOnly: _selectedFilterIndex == 0,
    level: _level,
  );

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: MatchColors.background,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final level in [
              'All levels',
              'Beginner',
              'Intermediate',
              'Advanced',
            ])
              ListTile(
                title: Text(level),
                trailing: (_level ?? 'All levels') == level
                    ? const Icon(Icons.check, color: MatchColors.primaryGreen)
                    : null,
                onTap: () => Navigator.pop(context, level),
              ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _level = result == 'All levels' ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MatchUiStore.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: MatchColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // 1. App Header (Height: 55)
              _buildAppHeader(context),

              // 2. Screen Content (Width 393, padding 24, gap 12)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tabs (345 × 34, gap 4)
                      _buildTabs(),
                      const SizedBox(height: 12),

                      // Filters (345 × 32, gap 7)
                      _buildFilters(),
                      const SizedBox(height: 12),

                      // Match Cards (4 cards, each 345 × 112, gap 12)
                      if (_visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matches found.'),
                        ),
                      ..._visible.map((match) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MatchCard(
                            match: match,
                            playerSummary:
                                MatchUiStore.instance.pending.contains(match.id)
                                ? 'Request pending'
                                : '${MatchUiStore.instance.participantsFor(match).length}/${match.draft?.requiredPlayers ?? match.players.split('/').last.split(' ').first} players${match.distance.isEmpty ? '' : ' · ${match.distance}'}',
                            onTap: () {
                              if (widget.onMatchDetail != null) {
                                widget.onMatchDetail!(match);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MatchDetailOpenScreen(
                                      match: match,
                                      draft: match.draft,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // 3. Bottom Navigation (Height: 84)
              PlayerBottomNavigation(
                currentTab: PlayerNavTab.match,
                onNavigateHome: widget.onNavigateHome,
                onNavigateMap: widget.onNavigateMap,
                onNavigateFeedback: widget.onNavigateFeedback,
                onNavigateProfile: widget.onNavigateProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. APP HEADER (393 × 55)
  // ==========================================
  Widget _buildAppHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: MatchColors.background,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              tooltip: 'Match Requests',
              icon: const Icon(
                Icons.inbox_outlined,
                color: MatchColors.primaryGreen,
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MatchInvitationsScreen(),
                ),
              ),
            ),
          ),
          // Centered Title: "Matches" (17 px Bold, #0D2630)
          Text(
            'Matches',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: MatchColors.darkText,
            ),
          ),

          // Create Match Button: 32 × 32, Radius 8, Background #05644F, Text "+" White 25 px Bold
          Positioned(
            right: 0,
            child: GestureDetector(
              onTap:
                  widget.onCreateMatch ??
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateMatchScreen(),
                      ),
                    );
                  },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MatchColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: MatchColors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. TABS (345 × 34, Gap 4)
  // ==========================================
  Widget _buildTabs() {
    return SizedBox(
      width: 345,
      height: 34,
      child: Row(
        children: [
          // Open Matches (170 × 34, Selected: bg #05644F, text White 12 px SemiBold)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = 0);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? MatchColors.primaryGreen
                      : MatchColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Open Matches',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedTabIndex == 0
                        ? MatchColors.white
                        : MatchColors.mutedText,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // My Matches (170 × 34, Unselected: bg #F7F8F5, text #66706E 12 px SemiBold)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = 1);
                if (widget.onMyMatches != null) {
                  widget.onMyMatches!();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? MatchColors.primaryGreen
                      : MatchColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'My Matches',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedTabIndex == 1
                        ? MatchColors.white
                        : MatchColors.mutedText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. FILTERS (345 × 32, Gap 7)
  // ==========================================
  Widget _buildFilters() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // Filter 1: Today (92 × 30, Selected: bg #DDF1E9, border 1px #D7DFDB, radius 10, text 11 px Medium #05644F)
          GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = 0),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 92,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedFilterIndex == 0
                    ? MatchColors.lightGreen
                    : MatchColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MatchColors.border, width: 1),
              ),
              child: Text(
                'Today',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MatchColors.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),

          // Filter 2: This week (94 × 26, bg #FFFFFF, radius 13, text 10 px SemiBold #0D2630)
          GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = 1),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 94,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedFilterIndex == 1
                    ? MatchColors.lightGreen
                    : MatchColors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                'This week',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _selectedFilterIndex == 1
                      ? MatchColors.primaryGreen
                      : MatchColors.darkText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),

          // Filter 3: Filter (42 × 26, bg #FFFFFF, radius 13, icon sprint5_filter.svg, text 10 px SemiBold #05644F)
          GestureDetector(
            onTap: _showFilters,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _level != null
                    ? MatchColors.lightGreen
                    : MatchColors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/sprint5_filter.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(
                      MatchColors.primaryGreen,
                      BlendMode.srcIn,
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

