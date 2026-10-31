import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

class FacilityCardItem {
  final int id;
  final String name;
  final String address;
  final int courtCount;
  final String operatingHours;
  final bool isOpen;
  final String? contactPhone;
  final String? description;

  const FacilityCardItem({
    required this.id,
    required this.name,
    required this.address,
    required this.courtCount,
    required this.operatingHours,
    this.isOpen = true,
    this.contactPhone,
    this.description,
  });
}

class FacilityCard extends StatelessWidget {
  final FacilityCardItem facility;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FacilityCard({
    super.key,
    required this.facility,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                    child: Opacity(
                      opacity: .22,
                      child: SvgPicture.asset(
                        'assets/icons/sprint4_court_pattern.svg',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 34,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: facility.isOpen
                          ? const Color(0xFFDDF1E9)
                          : const Color(0xFFFFE2E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      facility.isOpen ? 'Open' : 'Closed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: facility.isOpen
                            ? AppColors.primary
                            : AppColors.linkAction,
                      ),
                    ),
                  ),
                ),
                if (onEdit != null || onDelete != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: PopupMenuButton<String>(
                      tooltip: 'Facility actions',
                      icon: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onSelected: (v) {
                        if (v == 'edit') onEdit?.call();
                        if (v == 'delete') onDelete?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit facility'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete facility'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        facility.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 19 / 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        facility.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 22),
                        child: Text(
                          '${facility.courtCount} Courts',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        facility.isOpen
                            ? 'Open until ${facility.operatingHours.split('-').last.trim()}'
                            : 'Closed today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.textSecondary,
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
  );
}
