import 'dashboard_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dashboard_assets.dart';
import 'dashboard_widgets.dart';

/// The Figma chart series remain discrete SVGs; axes, selection and tooltips
/// are native widgets. These series are design fixtures until analytics APIs exist.
class DashboardTrendChart extends StatelessWidget {
  const DashboardTrendChart({
    super.key,
    required this.palette,
    required this.period,
    required this.onPeriod,
    this.growth = false,
  });
  final DashboardPalette palette;
  final String period;
  final VoidCallback onPeriod;
  final bool growth;

  @override
  Widget build(BuildContext context) {
    final prefix = growth ? 'admin' : 'owner';
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
                    ? 'User growth chart, demo data. Tap for details.'
                    : 'Booking trend chart, demo data. Tap for details.',
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
                (growth
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
  const DashboardPeakChart({super.key, required this.palette});
  final DashboardPalette palette;
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
                label: '${[6, 9, 12, 15, 18, 21][i]} hours, demo bookings',
                child: InkWell(
                  onTap: () => dashboardOptions(
                    context,
                    palette,
                    '${[6, 9, 12, 15, 18, 21][i]}:00',
                    [],
                    subtitle: 'Demo · ${[12, 25, 19, 34, 54, 31][i]} bookings',
                  ),
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
  const DashboardStatusChart({super.key, required this.palette});
  final DashboardPalette palette;
  @override
  Widget build(BuildContext context) => DashboardCard(
    palette: palette,
    onTap: () => dashboardOptions(
      context,
      palette,
      'Court Registration Status',
      [],
      subtitle: 'Illustrative data · Active 144, Pending 28, Inactive 14. Approval/status API not available.',
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
                          '186',
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
                        ['144 (77%)', '28 (15%)', '14 (8%)'][i],
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
