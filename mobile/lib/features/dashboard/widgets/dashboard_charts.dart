import 'dashboard_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/dashboard_repository.dart';
import 'dashboard_assets.dart';
import 'dashboard_widgets.dart';

/// The Figma chart series remain discrete SVGs; axes, selection and tooltips
/// are native widgets connected to live analytics data when available.
class DashboardTrendChart extends StatelessWidget {
  const DashboardTrendChart({
    super.key,
    required this.palette,
    required this.period,
    required this.onPeriod,
    this.growth = false,
    this.series,
    this.live = false,
  });
  final DashboardPalette palette;
  final String period;
  final VoidCallback onPeriod;
  final bool growth;
  final List<DashboardTrendPoint>? series;
  final bool live;

  List<DashboardTrendPoint> get _displaySeries {
    final raw = series;
    if (raw == null || raw.isEmpty) return const [];
    final maxPoints = growth ? 6 : 7;
    return raw.length <= maxPoints ? raw : raw.sublist(raw.length - maxPoints);
  }

  String _shortPeriod(String raw) {
    if (raw.length == 10 && raw[4] == '-' && raw[7] == '-') {
      final month = int.tryParse(raw.substring(5, 7)) ?? 1;
      final day = int.tryParse(raw.substring(8, 10)) ?? 1;
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[(month - 1).clamp(0, 11)]} $day';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final prefix = growth ? 'admin' : 'owner';
    final livePoints = _displaySeries;
    return DashboardCard(
      palette: palette,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  growth ? 'User Growth' : 'Booking Trend',
                  style: palette.text(16, weight: FontWeight.w600),
                ),
              ),
              InkWell(
                onTap: onPeriod,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 28),
                  child: Center(
                    child: Text(
                      period,
                      style: palette.text(
                        11,
                        weight: FontWeight.w500,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (live && livePoints.isNotEmpty) {
                  final count = livePoints.length;
                  final i = ((details.localPosition.dx / box.maxWidth) * count)
                      .floor()
                      .clamp(0, count - 1);
                  final pt = livePoints[i];
                  dashboardOptions(
                    context,
                    palette,
                    _shortPeriod(pt.period),
                    [],
                    subtitle:
                        'Live · ${pt.bookingCount} bookings · ${pt.revenue.round()}đ (${pt.bookedHours}h)',
                  );
                  return;
                }
                final count = growth ? 6 : 7;
                final i = ((details.localPosition.dx / box.maxWidth) * count)
                    .floor()
                    .clamp(0, count - 1);
                final dates = growth
                    ? ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']
                    : [
                        'Oct 28',
                        'Oct 29',
                        'Oct 30',
                        'Oct 31',
                        'Nov 1',
                        'Nov 2',
                        'Nov 3',
                      ];
                final values = growth
                    ? [6, 10, 14, 18, 23, 27]
                    : [58, 92, 80, 174, 158, 236, 280];
                dashboardOptions(
                  context,
                  palette,
                  dates[i],
                  [],
                  subtitle: growth
                      ? 'Demo · Players: ${values[i]} · Owners: ${[2, 3, 5, 6, 8, 10][i]}'
                      : 'Demo · ${values[i]} bookings',
                );
              },
              child: Semantics(
                button: true,
                label: growth
                    ? 'User growth chart, ${live ? "live" : "demo"} data. Tap for details.'
                    : 'Booking trend chart, ${live ? "live" : "demo"} data. Tap for details.',
                child: AspectRatio(
                  aspectRatio: 321 / 142,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: 321,
                      height: 142,
                      child: Stack(
                        children: [
                          for (var i = 0; i < (growth ? 4 : 5); i++) ...[
                            Positioned(
                              left: 0,
                              top: i * (growth ? 42.0 : 31.5),
                              child: Text(
                                '${(growth ? 30 : 320) - i * (growth ? 10 : 80)}',
                                style: palette.text(9, color: palette.muted),
                              ),
                            ),
                            Positioned(
                              left: 30,
                              right: 5,
                              top: 7 + i * (growth ? 42.0 : 31.5),
                              child: Container(
                                height: 1,
                                color: palette.border,
                              ),
                            ),
                          ],
                          Positioned(
                            left: 30,
                            top: growth ? 19 : 22,
                            width: 282,
                            height: growth ? 113 : 110,
                            child: DashboardChartReveal(
                              radial: false,
                              child: SvgPicture.asset(
                                dashboardAssets['$prefix.imgSeriesArea']!,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 28.75,
                            top: growth ? 17.75 : 20.75,
                            width: 284.5,
                            height: growth ? 90.5 : 88.5,
                            child: DashboardChartReveal(
                              radial: false,
                              child: SvgPicture.asset(
                                dashboardAssets['$prefix.imgSeriesPrimary']!,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          if (growth)
                            Positioned(
                              left: 28.75,
                              top: 86.75,
                              width: 284.5,
                              height: 38.5,
                              child: DashboardChartReveal(
                                radial: false,
                                child: SvgPicture.asset(
                                  dashboardAssets['admin.imgSeriesOwners']!,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 308.5,
                            top: growth ? 15.5 : 18.5,
                            width: 7,
                            height: 7,
                            child: DashboardChartReveal(
                              radial: false,
                              child: SvgPicture.asset(
                                dashboardAssets['$prefix.imgSelectedDataPoint']!,
                              ),
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
                (live && livePoints.isNotEmpty
                        ? livePoints
                              .map((pt) => _shortPeriod(pt.period))
                              .toList()
                        : growth
                        ? ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct']
                        : ['Oct 28', '29', '30', '31', 'Nov 1', '2', '3'])
                    .map(
                      (label) => Text(
                        label,
                        style: palette.text(9, color: palette.muted),
                      ),
                    )
                    .toList(),
          ),
          if (growth) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _legend(palette.brand, 'Players'),
                const SizedBox(width: 60),
                _legend(palette.accent, 'Owners'),
              ],
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: palette.text(10, weight: FontWeight.w500, color: palette.muted),
      ),
    ],
  );
}

class DashboardPeakChart extends StatelessWidget {
  const DashboardPeakChart({
    super.key,
    required this.palette,
    this.courts,
    this.live = false,
  });
  final DashboardPalette palette;
  final List<DashboardCourtUtilization>? courts;
  final bool live;
  @override
  Widget build(BuildContext context) => DashboardCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peak Booking Hours',
          style: palette.text(16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(
            6,
            (i) => Expanded(
              child: Semantics(
                button: true,
                label: '${[6, 9, 12, 15, 18, 21][i]} hours, bookings',
                child: InkWell(
                  onTap: () {
                    final courtList = courts;
                    if (live && courtList != null && courtList.isNotEmpty) {
                      final topCourt = courtList[i % courtList.length];
                      final rate = topCourt.utilizationRate != null
                          ? '${(topCourt.utilizationRate! * 100).toStringAsFixed(1)}%'
                          : 'N/A';
                      dashboardOptions(
                        context,
                        palette,
                        topCourt.courtName,
                        [],
                        subtitle:
                            'Live utilization · ${topCourt.bookingCount} bookings · ${topCourt.bookedHours}h / ${topCourt.availableHours}h ($rate)',
                      );
                      return;
                    }
                    dashboardOptions(
                      context,
                      palette,
                      '${[6, 9, 12, 15, 18, 21][i]}:00',
                      [],
                      subtitle: live
                          ? 'Hourly slot distribution is not exposed by the API.'
                          : 'Demo · ${[12, 25, 19, 34, 54, 31][i]} bookings',
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 27,
                        height: [24.0, 50.0, 38.0, 68.0, 108.0, 62.0][i],
                        child: DashboardChartReveal(
                          vertical: true,
                          child: Container(
                            width: 27,
                            height: [24.0, 50.0, 38.0, 68.0, 108.0, 62.0][i],
                            decoration: BoxDecoration(
                              color: i == 4 ? palette.brand : palette.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ['06', '09', '12', '15', '18', '21'][i],
                        style: palette.text(10, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class DashboardStatusChart extends StatelessWidget {
  const DashboardStatusChart({
    super.key,
    required this.palette,
    this.courts,
    this.totalCourts,
    this.live = false,
  });
  final DashboardPalette palette;
  final List<DashboardCourtUtilization>? courts;
  final int? totalCourts;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final courtList = courts ?? const <DashboardCourtUtilization>[];
    final int activeCount = live
        ? courtList.where((c) => c.status.toUpperCase() == 'ACTIVE').length
        : 144;
    final int pendingCount = live
        ? courtList
              .where((c) => c.status.toUpperCase() == 'MAINTENANCE')
              .length
        : 28;
    final int inactiveCount = live
        ? courtList
              .where(
                (c) =>
                    c.status.toUpperCase() != 'ACTIVE' &&
                    c.status.toUpperCase() != 'MAINTENANCE',
              )
              .length
        : 14;
    final int total = live ? (totalCourts ?? courtList.length) : 186;
    String pct(int count) =>
        total > 0 ? '$count (${((count * 100) / total).round()}%)' : '$count (0%)';

    return DashboardCard(
      palette: palette,
      onTap: () => dashboardOptions(
        context,
        palette,
        'Court Registration Status',
        [],
        subtitle: live
            ? 'Live court utilization · Active $activeCount, Maintenance $pendingCount, Inactive $inactiveCount.'
            : 'Illustrative data · Active 144, Pending 28, Inactive 14. Approval/status API not available.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Court Registration Status',
            style: palette.text(16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (_, box) {
              final chart = SizedBox.square(
                dimension: 142,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DashboardChartReveal(
                        radial: true,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: SvgPicture.asset(
                                dashboardAssets['system.imgSegmentAccent']!,
                              ),
                            ),
                            Positioned(
                              left: .82,
                              top: 8.62,
                              width: 46.43,
                              height: 54.85,
                              child: SvgPicture.asset(
                                dashboardAssets['system.imgSegmentWarning']!,
                                fit: BoxFit.fill,
                              ),
                            ),
                            Positioned(
                              left: 38.67,
                              top: 0,
                              width: 31.10,
                              height: 26.75,
                              child: SvgPicture.asset(
                                dashboardAssets['system.imgSegmentDanger']!,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DashboardCount(
                            '$total',
                            style: palette.text(28, weight: FontWeight.w700),
                          ),
                          Text(
                            'Courts',
                            style: palette.text(12, color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final legendValues = live
                  ? [
                      pct(activeCount),
                      pct(pendingCount),
                      pct(inactiveCount),
                    ]
                  : ['144 (77%)', '28 (15%)', '14 (8%)'];
              final legend = Column(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: [
                              palette.accent,
                              const Color(0xFFF3A838),
                              const Color(0xFFF46C68),
                            ][i],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ['Active', 'Pending', 'Inactive'][i],
                            style: palette.text(11, weight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          legendValues[i],
                          style: palette.text(10, color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              return box.maxWidth < 280
                  ? Column(children: [chart, legend])
                  : Row(
                      children: [
                        chart,
                        const SizedBox(width: 16),
                        Expanded(child: legend),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}
