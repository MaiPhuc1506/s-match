import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../booking/screens/booking_facility_schedule_screen.dart';
import '../../court_map/exploration_data.dart';
import '../../court_map/screens/court_preview_screen.dart';
import '../../court_map/screens/find_courts_map_screen.dart';
import '../../court_map/widgets/facility_gallery.dart';

class CourtChatCard extends ConsumerWidget {
  const CourtChatCard({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = (data['facilityId'] as num?)?.toInt();
    if (id == null || id <= 0) return const SizedBox.shrink();
    final detail = ref.watch(facilityDetailProvider(id));
    final facility = detail.valueOrNull;
    final name = facility?.name ?? data['name']?.toString() ?? '';
    final address = facility?.address ?? data['address']?.toString() ?? '';
    final courts = (data['courts'] as List?)?.whereType<Map>().toList() ?? [];
    final prices = <num>[];
    for (final court in courts) {
      if (court['minPriceVnd'] is num) prices.add(court['minPriceVnd'] as num);
      for (final slot in (court['sampleAvailableSlots'] as List? ?? [])) {
        if (slot is Map && slot['hourlyRateVnd'] is num) {
          prices.add(slot['hourlyRateVnd'] as num);
        }
      }
    }
    prices.sort();
    final types = courts
        .map((c) => c['courtType']?.toString())
        .whereType<String>()
        .toSet();
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    String currency(num value) {
      final digits = value.round().toString();
      final separator = vi ? '.' : ',';
      final result = digits.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => separator,
      );
      return vi ? '$result đ' : '$result VND';
    }

    void openMap() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FindCourtsMapScreen(initialFacilityId: id),
      ),
    );
    Future<void> externalDirections() async {
      if (facility?.hasCoordinates != true) return;
      final uri = Uri.https('maps.apple.com', '/', {
        'daddr': '${facility!.latitude},${facility.longitude}',
        'dirflg': 'd',
      });
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open directions.')),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE8E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 80,
                  child: facility != null && facility.photos.isNotEmpty
                      ? FacilityPhoto(
                          facility.photos.first,
                          key: ValueKey('$id:${facility.photos.first}'),
                        )
                      : const ColoredBox(
                          color: Color(0xFFEAF6EF),
                          child: Icon(
                            CupertinoIcons.sportscourt,
                            color: Color(0xFF05644F),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF687A73),
                        ),
                      ),
                    if (types.isNotEmpty)
                      Text(
                        types
                            .map(
                              (t) => t.toLowerCase() == 'indoor'
                                  ? 'Indoor'
                                  : t.toLowerCase() == 'outdoor'
                                  ? 'Outdoor'
                                  : t,
                            )
                            .join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF05644F),
                        ),
                      ),
                    if (prices.isNotEmpty)
                      Text(
                        '${vi ? 'Từ' : 'From'} ${currency(prices.first)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (data['distanceKm'] is num)
                      Text(
                        '${(data['distanceKm'] as num).toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF05644F),
                        ),
                      ),
                    if (data['matchingCourtsCount'] is num)
                      Text(
                        '${data['matchingCourtsCount']} matching courts',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(44, 44),
                color: const Color(0xFF05644F),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        BookingFacilityScheduleScreen(facilityId: id),
                  ),
                ),
                child: const Text(
                  'Book now',
                  style: TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
                onPressed: facility == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CourtPreviewScreen(location: facility),
                        ),
                      ),
                child: const Text(
                  'View details',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
                onPressed: openMap,
                child: const Text(
                  'View on map',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (facility?.hasCoordinates == true)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44),
                  onPressed: externalDirections,
                  child: const Text(
                    'Directions',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
