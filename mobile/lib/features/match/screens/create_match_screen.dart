import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_model.dart';
import '../state/match_ui_store.dart';
import 'match_detail_open_screen.dart';

/// Screen 02: Create Match (Figma Node 413:904)
/// Reference Viewport: 393 × 852, Background: #F7F8F5
class CreateMatchScreen extends StatefulWidget {
  /// Opens directly in the private state shown in Figma 413:1088.
  final bool initiallyPrivate;
  final VoidCallback? onPrivateMatchTap;
  final VoidCallback? onCreateMatchSubmit;

  const CreateMatchScreen({
    super.key,
    this.initiallyPrivate = false,
    this.onPrivateMatchTap,
    this.onCreateMatchSubmit,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  // Trạng thái theo đúng Figma Verified State (Section 7)
  bool _isOpenMatch = true; // Open Match = Selected
  bool _isDoubles = true; // Singles = Unselected, Doubles = Selected
  int _requiredPlayers = 4; // Required Players = 4
  int _selectedLevelIndex =
      1; // 0: Beginner, 1: Intermediate (Selected), 2: Advanced

  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _isOpenMatch = !widget.initiallyPrivate;
    _titleController = TextEditingController(text: 'Weekend Doubles Fun');
    _descController = TextEditingController(
      text: 'Casual match, all are welcome! 🏸',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatchColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. App Header (Height: 55)
            _buildAppHeader(context),

            // 2. Screen Content (Width: 393, Content Width: 345, Padding: 24, Gap: 12)
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: _isOpenMatch ? 12 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2.1 Open / Private Match Selector (345 × 34)
                    _buildVisibilitySelector(),
                    const SizedBox(height: 12),

                    // 2.2 Title Field (345 × 58)
                    _isOpenMatch
                        ? _buildTitleField()
                        : SizedBox(height: 58, child: _buildTitleField()),
                    const SizedBox(height: 12),

                    // 2.3 Description Field (345 × 74)
                    _isOpenMatch
                        ? _buildDescriptionField()
                        : SizedBox(height: 74, child: _buildDescriptionField()),
                    const SizedBox(height: 12),

                    // 2.4 Selected Facility Card (345 × 62)
                    _buildSelectedFacilityCard(),
                    const SizedBox(height: 12),

                    // 2.5 Date Field (345 × 42)
                    _buildDateField(),
                    const SizedBox(height: 12),

                    // 2.6 Time Field (345 × 42)
                    _buildTimeField(),
                    const SizedBox(height: 12),

                    // 2.7 Game Type (345 × 34)
                    _buildGameTypeSelector(),
                    const SizedBox(height: 12),

                    // 2.8 Required Players (345 × 34)
                    _buildRequiredPlayersStepper(),
                    const SizedBox(height: 12),

                    // 2.9 Preferred Level (345 × 30)
                    _buildPreferredLevelSelector(),
                    SizedBox(height: _isOpenMatch ? 16 : 12),

                    // 2.10 Create Match Button (345 × 42)
                    _buildCreateMatchButton(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: MatchColors.background,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Nút Back "‹" (28 px Regular 400, #0D2630)
          Positioned(
            left: 0,
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '‹',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: MatchColors.darkText,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // Title "Create Match" (17 px Bold 700, #0D2630)
          Text(
            'Create Match',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: MatchColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2.1 OPEN / PRIVATE SELECTOR (345 × 34)
  // ==========================================
  Widget _buildVisibilitySelector() {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: Row(
        children: [
          // Open Match (170 × 34, Selected: bg #05644F, text White 12 px SemiBold)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isOpenMatch = true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isOpenMatch
                      ? MatchColors.primaryGreen
                      : MatchColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Open Match',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isOpenMatch
                        ? MatchColors.white
                        : MatchColors.mutedText,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Private Match (170 × 34, Unselected: bg #F7F8F5, text #66706E 12 px SemiBold)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isOpenMatch = false);
                if (widget.onPrivateMatchTap != null) {
                  widget.onPrivateMatchTap!();
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
                  color: !_isOpenMatch
                      ? MatchColors.primaryGreen
                      : MatchColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Private Match',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !_isOpenMatch
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
  // 2.2 TITLE FIELD (345 × 58)
  // ==========================================
  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Title',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MatchColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 38,
          decoration: BoxDecoration(
            color: MatchColors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: MatchColors.border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _titleController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MatchColors.darkText,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2.3 DESCRIPTION FIELD (345 × 74)
  // ==========================================
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MatchColors.darkText,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: MatchColors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: MatchColors.border, width: 1),
          ),
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _descController,
            maxLines: 2,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MatchColors.darkText,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2.4 SELECTED FACILITY CARD (345 × 62)
  // ==========================================
  Widget _buildSelectedFacilityCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Court / Facility',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MatchColors.darkText,
          ),
        ),
        SizedBox(height: _isOpenMatch ? 4 : 12),
        Container(
          width: double.infinity,
          height: 62,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: MatchColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: MatchColors.border, width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 56,
                  height: 46,
                  child: _isOpenMatch
                      ? SvgPicture.asset(
                          'assets/icons/sprint4_court_thumbnail.svg',
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'assets/images/match/facility_court.jpg',
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sunrise Badminton Club',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MatchColors.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Da Nang, Vietnam',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: MatchColors.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2.5 DATE FIELD (345 × 42)
  // ==========================================
  Widget _buildDateField() {
    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: MatchColors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: MatchColors.border, width: 1),
      ),
      child: Row(
        children: [
          _isOpenMatch
              ? SvgPicture.asset(
                  'assets/icons/sprint4_calendar.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    MatchColors.primaryGreen,
                    BlendMode.srcIn,
                  ),
                )
              : Text(
                  '▣',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    color: MatchColors.primaryGreen,
                  ),
                ),
          const SizedBox(width: 8),
          Text(
            MatchUiStore.dateLabel(DateTime.now()),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MatchColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2.6 TIME FIELD (345 × 42)
  // ==========================================
  Widget _buildTimeField() {
    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: MatchColors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: MatchColors.border, width: 1),
      ),
      child: Row(
        children: [
          _isOpenMatch
              ? SvgPicture.asset(
                  'assets/icons/sprint4_clock.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(
                    MatchColors.primaryGreen,
                    BlendMode.srcIn,
                  ),
                )
              : Text(
                  '◷',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    color: MatchColors.primaryGreen,
                  ),
                ),
          const SizedBox(width: 8),
          Text(
            '19:00 – 21:00 (2 hours)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: MatchColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2.7 GAME TYPE SELECTOR (345 × 34)
  // ==========================================
  Widget _buildGameTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Game Type',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MatchColors.darkText,
          ),
        ),
        SizedBox(height: _isOpenMatch ? 4 : 12),
        SizedBox(
          width: double.infinity,
          height: 34,
          child: Row(
            children: [
              // Singles (168 × 34)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoubles = false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: !_isDoubles
                          ? MatchColors.primaryGreen
                          : MatchColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Singles',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: !_isDoubles
                            ? MatchColors.white
                            : MatchColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Doubles (168 × 34, Selected: bg #05644F)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isDoubles = true),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _isDoubles
                          ? MatchColors.primaryGreen
                          : MatchColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Doubles',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isDoubles
                            ? MatchColors.white
                            : MatchColors.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2.8 REQUIRED PLAYERS STEPPER (345 × 34)
  // ==========================================
  Widget _buildRequiredPlayersStepper() {
    return SizedBox(
      width: double.infinity,
      height: 34,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Required Players',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MatchColors.darkText,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_requiredPlayers > 2) {
                    setState(() => _requiredPlayers--);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '－',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: MatchColors.darkText,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    '$_requiredPlayers',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: MatchColors.darkText,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _requiredPlayers++);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '＋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: MatchColors.darkText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2.9 PREFERRED LEVEL (345 × 30)
  // ==========================================
  Widget _buildPreferredLevelSelector() {
    final levels = [
      ('Beginner', 103),
      ('Intermediate', 126),
      ('Advanced', 105),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Level',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: MatchColors.darkText,
          ),
        ),
        SizedBox(height: _isOpenMatch ? 4 : 12),
        SizedBox(
          width: double.infinity,
          height: 30,
          child: Row(
            children: [
              for (var index = 0; index < levels.length; index++) ...[
                Expanded(
                  flex: levels[index].$2,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedLevelIndex = index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _selectedLevelIndex == index
                            ? MatchColors.primaryGreen
                            : MatchColors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        levels[index].$1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _selectedLevelIndex == index
                              ? MatchColors.white
                              : MatchColors.darkText,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index < levels.length - 1) const SizedBox(width: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2.10 CREATE MATCH BUTTON (345 × 42)
  // ==========================================
  Widget _buildCreateMatchButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: MatchColors.primaryGreen,
          foregroundColor: MatchColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        onPressed: () {
          final title = _titleController.text.trim();
          if (title.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a match title.')),
            );
            return;
          }
          FocusScope.of(context).unfocus();
          if (widget.onCreateMatchSubmit != null) {
            widget.onCreateMatchSubmit!();
          } else {
            final draft = MatchDraft(
              title: title,
              description: _descController.text.trim(),
              isPrivate: !_isOpenMatch,
              gameType: _isDoubles ? 'Doubles' : 'Singles',
              requiredPlayers: _requiredPlayers,
              skillLevel: const [
                'Beginner',
                'Intermediate',
                'Advanced',
              ][_selectedLevelIndex],
            );
            final match = MatchUiStore.instance.create(draft);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    MatchDetailOpenScreen(match: match, draft: draft),
              ),
            );
          }
        },
        child: Text(
          'Create Match',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MatchColors.white,
          ),
        ),
      ),
    );
  }
}
