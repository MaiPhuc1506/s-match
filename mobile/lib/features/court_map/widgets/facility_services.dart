import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'exploration_widgets.dart';

String facilityPrice(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

// Collapse only adjacent one-hour slots at the same price. The displayed price
// stays an hourly unit; arbitrary API intervals are never relabelled per-hour.
List<Map<String, dynamic>> _priceRanges(List<Map<String, dynamic>> rows) {
  int minutes(Object? time) {
    final parts = time.toString().split(':');
    if (parts.length < 2) return -10000;
    return (int.tryParse(parts[0]) ?? -1000) * 60 +
        (int.tryParse(parts[1]) ?? -1000);
  }

  final result = <Map<String, dynamic>>[];
  for (final row in rows) {
    final hourly =
        row['hourlyRate'] is num ||
        minutes(row['endTime']) - minutes(row['startTime']) == 60;
    if (hourly &&
        result.isNotEmpty &&
        result.last['hourly'] == true &&
        result.last['endTime'] == row['startTime'] &&
        result.last['price'] == row['price'] &&
        result.last['walkInPrice'] == row['walkInPrice']) {
      result.last['endTime'] = row['endTime'];
    } else {
      result.add({...row, 'hourly': hourly});
    }
  }
  return result;
}

const _green = Color(0xFF05644F);

/// Groups only identical court/day tariffs. Prices retain the API's slot unit.
List<({String courts, String days, List<Map<String, dynamic>> rows})>
facilityTariffs(List<Map<String, dynamic>> courts) {
  final groups =
      <
        String,
        ({Set<String> courts, Set<int> days, List<Map<String, dynamic>> rows})
      >{};
  for (final court in courts) {
    if (court['status'] != null && court['status'] != 'ACTIVE') continue;
    final days = <int, List<Map<String, dynamic>>>{};
    for (final raw in court['timeSlots'] as List? ?? []) {
      if (raw is! Map ||
          raw['isActive'] == false ||
          raw['price'] is! num ||
          raw['dayOfWeek'] is! int) {
        continue;
      }
      final row = Map<String, dynamic>.from(raw);
      if (row['hourlyRate'] is num) {
        final start = row['startTime']
            .toString()
            .split(':')
            .map(int.parse)
            .toList();
        final end = row['endTime']
            .toString()
            .split(':')
            .map(int.parse)
            .toList();
        final duration = (end[0] - start[0]) * 60 + end[1] - start[1];
        row['price'] = row['hourlyRate'];
        if (row['walkInPrice'] is num && duration > 0) {
          row['walkInPrice'] = (row['walkInPrice'] as num) * 60 / duration;
        }
      }
      days.putIfAbsent(row['dayOfWeek'] as int, () => []).add(row);
    }
    for (final entry in days.entries) {
      final rows = entry.value
        ..sort(
          (a, b) =>
              a['startTime'].toString().compareTo(b['startTime'].toString()),
        );
      // Keep each API interval: a slot price is not necessarily an hourly rate.
      final rowKey = rows
          .map(
            (r) =>
                '${r['startTime']}|${r['endTime']}|${r['price']}|${r['walkInPrice']}',
          )
          .join(';');
      final signature = '${court['id'] ?? court['name']}:$rowKey';
      final group = groups.putIfAbsent(
        signature,
        () => (courts: <String>{}, days: <int>{}, rows: rows),
      );
      group.courts.add(court['name']?.toString() ?? 'Court');
      group.days.add(entry.key);
    }
  }
  final consolidated =
      <
        String,
        ({Set<String> courts, Set<int> days, List<Map<String, dynamic>> rows})
      >{};
  for (final group in groups.values) {
    final dayKey = (group.days.toList()..sort()).join(',');
    final rowKey = group.rows
        .map(
          (r) =>
              '${r['startTime']}|${r['endTime']}|${r['price']}|${r['walkInPrice']}',
        )
        .join(';');
    final key = '$dayKey:$rowKey';
    final target = consolidated.putIfAbsent(
      key,
      () => (courts: <String>{}, days: group.days, rows: group.rows),
    );
    target.courts.addAll(group.courts);
  }
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return consolidated.values
      .map(
        (g) => (
          courts: g.courts.join(' · '),
          days: g.days.length == 7
              ? 'Mon–Sun'
              : (g.days.toList()..sort())
                    .map((d) => d >= 0 && d < 7 ? names[d] : 'Unknown')
                    .join(', '),
          rows: _priceRanges(g.rows),
        ),
      )
      .toList();
}

/// A published service, supplied by the caller; an empty list stays empty.
class FacilityServiceItem {
  const FacilityServiceItem({
    required this.name,
    this.price,
    this.unit,
    this.category,
  });
  final String name;
  final num? price;
  final String? unit;
  final String? category;
}

/// The approved four-column composition, populated only by supplied tariffs.
class FacilityServices extends StatelessWidget {
  const FacilityServices({
    super.key,
    required this.courts,
    this.services = const [],
  });
  final List<Map<String, dynamic>> courts;
  final List<FacilityServiceItem> services;
  static const ink = Color(0xFF1C1C1C);
  static const muted = Color(0xFF6B6B6B);
  static const mint = Color(0xFFEEF7F3);

  static Widget glyph(String name, double size, {Color color = _green}) =>
      SizedBox.square(
        dimension: size,
        child: Center(
          child: SvgPicture.asset(
            'assets/sprint10/icons/facility_$name.svg',
            // Original vector bounds sit inside Figma's 24-point icon frame.
            width: size * .82,
            height: size * .82,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      );

  TextStyle type(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double? line,
  }) => exploreText(size, weight: weight, color: color, line: line);

  String courtGroup(String names) {
    final values = names.split(' · ');
    final numbers = values
        .map((n) => RegExp(r'^Court (\d+)$').firstMatch(n))
        .toList();
    if (numbers.every((n) => n != null)) {
      final ids = numbers.map((n) => int.parse(n!.group(1)!)).toList()..sort();
      if (ids.length > 1 && ids.last - ids.first + 1 == ids.length) {
        final types = courts.map((c) => c['courtType']).toSet();
        return 'Courts ${ids.first}–${ids.last}${types.length == 1 && types.single == 'INDOOR' ? ' · Indoor' : ''}';
      }
    }
    return names;
  }

  Widget badge(String icon, {double size = 36}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: mint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(child: glyph(icon, 22)),
  );

  @override
  Widget build(BuildContext context) {
    final groups = facilityTariffs(courts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
          child: Row(
            children: [
              badge('tag'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Court pricing',
                      style: type(14, weight: FontWeight.w600, line: 19),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      groups.length == 1
                          ? courtGroup(groups.single.courts)
                          : 'Court groups & hourly rates',
                      style: type(11, color: muted, line: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Opacity(
                opacity: .5,
                child: Image.asset(
                  'assets/sprint10/icons/facility_shuttle.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Text('No pricing available yet.', style: type(12, color: muted)),
        for (final group in groups) ...[
          if (groups.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                courtGroup(group.courts),
                style: type(11, color: muted),
              ),
            ),
          _table(context, group.days, group.rows),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              glyph('calendar', 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  groups.every((g) => g.rows.every((r) => r['hourly'] == true))
                      ? (groups.every(
                              (g) =>
                                  g.rows.every((r) => r['walkInPrice'] is num),
                            )
                            ? 'Rates per hour · Booking uses the fixed price.'
                            : 'Rates per hour · Walk-in prices not provided.')
                      : 'Rates per slot · Walk-in prices not provided.',
                  style: type(11, color: _green, line: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            badge('handshake', size: 32),
            const SizedBox(width: 10),
            Text(
              'Services',
              style: type(14, weight: FontWeight.w600, line: 19),
            ),
            const Spacer(),
            if (services.isNotEmpty)
              Text(
                '${services.length} listed',
                style: type(12, color: muted, line: 17),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('facility-service-list'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD6DCD8), width: .5),
          ),
          child: services.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      badge('handshake', size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No services listed yet',
                              style: type(
                                12,
                                weight: FontWeight.w500,
                                line: 17,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Service details will appear when the facility publishes them.',
                              style: type(11, color: muted, line: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < services.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 16, thickness: .5, indent: 44),
                      Row(
                        children: [
                          badge(
                            services[i].category == 'BEVERAGE'
                                ? 'bottle'
                                : 'tag',
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              services[i].name,
                              style: type(12, line: 17),
                            ),
                          ),
                          if (services[i].price != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: mint,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${facilityPrice(services[i].price!)} ₫${services[i].unit == null ? '' : ' / ${services[i].unit}'}',
                                style: type(
                                  11,
                                  color: _green,
                                  weight: FontWeight.w500,
                                  line: 17,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _table(
    BuildContext context,
    String days,
    List<Map<String, dynamic>> rows,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = (constraints.maxWidth - 27) / 330;
      final widths = [74, 94, 84, 78].map((w) => w * scale).toList();
      final rowHeight = (MediaQuery.textScalerOf(context).scale(17) + 23).clamp(
        40.0,
        double.infinity,
      );
      final hourly = rows.every((r) => r['hourly'] == true);
      return Container(
        key: const Key('facility-pricing-table'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: _green,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  _heading('calendar', 'Day', widths[0]),
                  const SizedBox(width: 5),
                  _heading('clock', 'Time range', widths[1]),
                  const SizedBox(width: 5),
                  _heading(
                    'coins',
                    hourly ? 'Fixed price' : 'Slot price',
                    widths[2],
                  ),
                  const SizedBox(width: 5),
                  _heading('crown', 'Walk-in', widths[3]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: widths[0],
                    constraints: BoxConstraints(
                      minHeight:
                          rows.length * rowHeight + (rows.length - 1) * 5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    decoration: BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SizedBox(
                      height:
                          (rows.length * rowHeight + (rows.length - 1) * 5 - 16)
                              .clamp(72, double.infinity),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          glyph('calendar', 25),
                          const SizedBox(height: 8),
                          Text(
                            days,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: type(
                              11.5,
                              weight: FontWeight.w500,
                              line: 17,
                            ),
                          ),
                          if (days == 'Mon–Sun') ...[
                            const SizedBox(height: 5),
                            Text(
                              'All week',
                              maxLines: 1,
                              softWrap: false,
                              style: type(10, color: muted, line: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          Row(
                            children: [
                              _cell(
                                '${rows[i]['startTime']}–${rows[i]['endTime']}',
                                widths[1],
                                rowHeight,
                                const Color(0xFFF6F7F7),
                              ),
                              const SizedBox(width: 5),
                              _cell(
                                '${facilityPrice(rows[i]['price'] as num)} ₫',
                                widths[2],
                                rowHeight,
                                (rows[i]['price'] as num) >
                                        (rows.first['price'] as num)
                                    ? const Color(0xFFFFF0F0)
                                    : mint,
                                price: true,
                              ),
                              const SizedBox(width: 5),
                              _cell(
                                rows[i]['walkInPrice'] is num
                                    ? '${facilityPrice(rows[i]['walkInPrice'] as num)} ₫'
                                    : '—',
                                widths[3],
                                rowHeight,
                                const Color(0xFFFFF9EA),
                                price: true,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _heading(String icon, String label, double width) => SizedBox(
    width: width,
    height: 40,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        glyph(icon, 16, color: Colors.white),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: type(
            11,
            color: Colors.white,
            weight: FontWeight.w500,
            line: 16,
          ),
        ),
      ],
    ),
  );
  Widget _cell(
    String value,
    double width,
    double height,
    Color color, {
    bool price = false,
  }) => Container(
    width: width,
    height: height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      value,
      maxLines: 1,
      style: type(
        11.5,
        weight: price ? FontWeight.w600 : FontWeight.w400,
        color: price ? _green : ink,
        line: 17,
      ),
    ),
  );
}
