import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_model.dart';

/// Reusable Component: Match Card (Figma Node 413:792)
/// Size: 345 × 112, Radius: 12, Border: 1 px #D7DFDB
class MatchCard extends StatelessWidget {
  final MatchItem match;
  final VoidCallback? onTap;
  final String? playerSummary;

  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.playerSummary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 345,
        height: 112,
        decoration: BoxDecoration(
          color: MatchColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MatchColors.border, width: 1),
        ),
        child: Stack(
          children: [
            // 1. Court Thumbnail at (13, 18), size 72 × 76, radius 8
            Positioned(
              left: 13,
              top: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 76,
                  child: SvgPicture.asset(
                    'assets/icons/sprint4_court_thumbnail.svg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // 2. Match Summary at (93, 14), height 84
            Positioned(
              left: 93,
              top: 14,
              right: 32,
              child: SizedBox(
                height: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Match title: 13 px Bold, #0D2630
                    Text(
                      match.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: MatchColors.darkText,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Skill Level Badge at (93, 29) relative to card (height: 20, radius: 10)
                    Container(
                      width: match.badgeWidth,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: match.badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        match.skillLevel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: match.badgeTextColor,
                          height: 1.0,
                        ),
                      ),
                    ),

                    // Metadata line 1: Date & Time (10 px Regular, #66706E)
                    Text(
                      match.time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: MatchColors.mutedText,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Metadata line 2: Facility name (10 px Regular, #66706E)
                    Text(
                      match.facility,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: MatchColors.mutedText,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Metadata line 3: Players & distance (10 px Regular, #66706E)
                    Text(
                      playerSummary ?? match.players,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: MatchColors.mutedText,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Chevron Right at (317, 48), size 16 × 16
            Positioned(
              left: 317,
              top: 48,
              child: SvgPicture.asset(
                'assets/icons/sprint4_chevron_right.svg',
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  MatchColors.primaryGreen,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
