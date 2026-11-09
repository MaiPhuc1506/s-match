import 'dart:math' as math;

import 'dashboard_motion.dart';
import '../../navigation/player_bottom_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_motion.dart';
import '../../court_map/widgets/exploration_widgets.dart' show exploreText;
import '../data/dashboard_repository.dart';
import 'dashboard_assets.dart';

class DashboardPalette {
  const DashboardPalette(this.role);
  final DashboardRole role;
  bool get admin => role == DashboardRole.admin;
  Color get brand => Color(admin ? 0xFF142D46 : 0xFF05644F);
  Color get accent => Color(admin ? 0xFF167D8D : 0xFF15A475);
  Color get background => Color(admin ? 0xFFF2F5F8 : 0xFFF7F8F5);
  Color get soft => Color(admin ? 0xFFE8F1F7 : 0xFFEAF6EF);
  Color get ink => Color(admin ? 0xFF152B3C : 0xFF1C1C1C);
  Color get muted => Color(admin ? 0xFF607386 : 0xFF6B6B6B);
  Color get border => Color(admin ? 0xFFDCE4EB : 0xFFD6DCD8);
  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => exploreText(
    size,
    weight: weight,
    color: color ?? ink,
    line: (size * 1.4).roundToDouble(),
  );
}

class DashboardAsset extends StatelessWidget {
  const DashboardAsset(this.slot, {super.key, this.size = 20, this.color});
  final String slot;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final path = dashboardAssets[slot]!;
    return SizedBox.square(
      dimension: size,
      child: path.endsWith('.svg')
          ? SvgPicture.asset(
              path,
              colorFilter: color == null
                  ? null
                  : ColorFilter.mode(color!, BlendMode.srcIn),
            )
          : Image.asset(path, fit: BoxFit.contain),
    );
  }
}

class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });
  final DashboardPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DashboardPress(
    enabled: onTap != null,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class DashboardControl extends StatelessWidget {
  const DashboardControl({
    super.key,
    required this.label,
    required this.child,
    required this.onTap,
  });
  final String label;
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: EdgeInsets.zero,
    icon: child,
  );
}

class DashboardPill extends StatelessWidget {
  const DashboardPill(
    this.label, {
    super.key,
    required this.palette,
    this.selected = false,
    this.status = false,
    this.onTap,
  });
  final String label;
  final DashboardPalette palette;
  final bool selected, status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    Color bg = selected ? palette.brand : palette.soft;
    Color fg = selected ? Colors.white : palette.muted;
    if (status) {
      bg = label == 'Pending'
          ? const Color(0xFFFFF1D6)
          : label == 'Cancelled' || label == 'Suspended'
          ? const Color(0xFFFCE6E4)
          : const Color(0xFFE0F3E7);
      fg = label == 'Pending'
          ? const Color(0xFF8A520A)
          : label == 'Cancelled' || label == 'Suspended'
          ? const Color(0xFFAD2929)
          : const Color(0xFF087A61);
    }
    final content = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: palette.text(12, weight: FontWeight.w600, color: fg),
      ),
    );
    return onTap == null
        ? content
        : Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(child: content),
              ),
            ),
          );
  }
}

class DashboardSelector extends StatelessWidget {
  const DashboardSelector(
    this.label, {
    super.key,
    required this.palette,
    required this.onTap,
    this.icon = 'owner.imgIconCalendar',
    this.chevron = 'owner.imgFrame4',
  });
  final String label;
  final String icon, chevron;
  final DashboardPalette palette;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DashboardCard(
    palette: palette,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    onTap: onTap,
    child: SizedBox(
      height: 44,
      child: Row(
        children: [
          DashboardAsset(icon, size: 18, color: palette.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: palette.text(13, weight: FontWeight.w600),
            ),
          ),
          DashboardAsset(chevron, size: 16, color: palette.muted),
        ],
      ),
    ),
  );
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric(
    this.label,
    this.value,
    this.detail, {
    super.key,
    required this.palette,
    required this.icon,
    this.compact = false,
    this.onTap,
  });
  final String label, value, detail, icon;
  final DashboardPalette palette;
  final bool compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DashboardCard(
    palette: palette,
    padding: const EdgeInsets.all(12),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 82 : 86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DashboardAsset(icon, size: 18, color: palette.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: palette.text(
                    compact ? 10 : 12,
                    weight: FontWeight.w500,
                    color: palette.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value.contains(':')
                ? Text(
                    value,
                    style: palette.text(
                      compact ? 22 : 24,
                      weight: FontWeight.w700,
                    ),
                  )
                : DashboardCount(
                    value,
                    key: ValueKey(label),
                    style: palette.text(
                      compact ? 22 : 24,
                      weight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: palette.text(
              compact ? 10 : 11,
              weight: FontWeight.w500,
              color: palette.brand,
            ),
          ),
        ],
      ),
    ),
  );
}

class DashboardBottomNavigation extends StatelessWidget {
  const DashboardBottomNavigation({
    super.key,
    required this.palette,
    required this.index,
    required this.onChanged,
  });
  final DashboardPalette palette;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final labels = palette.admin
        ? ['Overview', 'Users', 'Facilities', 'Analytics']
        : ['Home', 'Courts', 'Bookings', 'Analytics', 'Profile'];
    final assets = palette.admin
        ? [
            'owner.imgFrame1',
            'owner.imgVector',
            'admin.imgIconCalendar1',
            'owner.imgFrame2',
          ]
        : [
            'owner.imgFrame1',
            'bookings.imgIconCourt',
            'owner.imgIconCalendar',
            'owner.imgFrame2',
            'owner.imgVector',
          ];
    return Container(
      height: PlayerBottomNavigation.heightFor(context),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          8,
          12,
          math.max(22, MediaQuery.viewPaddingOf(context).bottom),
        ),
        child: Row(
          children: List.generate(
            labels.length,
            (i) => Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: labels[i],
                child: InkWell(
                  key: ValueKey('dashboard-tab-$i'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, 200),
                    height: PlayerBottomNavigation.itemHeightFor(context),
                    decoration: BoxDecoration(
                      color: i == index ? palette.soft : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: i == index ? 1 : .6,
                          child: DashboardAsset(
                            assets[i],
                            size: 22,
                            color: i == index ? palette.brand : palette.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: palette.text(
                            12,
                            color: i == index ? palette.brand : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> dashboardOptions(
  BuildContext context,
  DashboardPalette p,
  String title,
  List<String> options, {
  String? subtitle,
}) => showModalBottomSheet<String>(
  context: context,
  backgroundColor: Colors.white,
  showDragHandle: true,
  isScrollControlled: true,
  sheetAnimationStyle: AnimationStyle(
    duration: AppMotion.duration(context, 250),
    reverseDuration: AppMotion.duration(context, 200),
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (sheetContext) => SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: p.text(20, weight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(subtitle, style: p.text(12, color: p.muted)),
              ),
            ...options.map(
              (option) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option, style: p.text(14)),
                trailing: Icon(Icons.chevron_right, color: p.muted),
                onTap: () => Navigator.pop(sheetContext, option),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
