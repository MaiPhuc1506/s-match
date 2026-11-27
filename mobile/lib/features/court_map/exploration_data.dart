import '../../core/network/api_client.dart';
import 'facility_images.dart';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit, replaceable UI fixtures: no coordinates or API contracts are implied.
/// A permitted public playing area, never a private player GPS fix.
class DiscoveryPlayingArea {
  const DiscoveryPlayingArea(
    this.name,
    this.latitude,
    this.longitude, {
    required this.permitted,
  });
  final String name;
  final double latitude, longitude;
  final bool permitted;
  bool get canDisplay =>
      permitted &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

class NearbyPlayer {
  const NearbyPlayer(
    this.id,
    this.name,
    this.level,
    this.distance,
    this.avatar,
    this.mode,
    this.style,
    this.marker, {
    this.listed = true,
    this.playingArea,
    this.availableNow,
    this.demo = false,
  });
  final String id, name, level, avatar, mode, style;
  final double distance;
  final Offset marker;
  final bool listed;
  final DiscoveryPlayingArea? playingArea;
  final bool? availableNow;
  final bool demo;
  bool get hasPublicLocation => playingArea?.canDisplay ?? false;
  String get availabilityText => availableNow == null
      ? 'Availability not shared'
      : availableNow!
      ? 'Available now'
      : 'Not available now';
}

const demoPlayers = [
  NearbyPlayer(
    'minh',
    'Minh Quân',
    'Intermediate',
    1.2,
    'assets/images/match/host_nguyen_van_a_reference.png',
    'Doubles',
    'Balanced',
    Offset(76, 32),
    playingArea: DiscoveryPlayingArea(
      'Hai Chau playing area',
      16.0618,
      108.2108,
      permitted: true,
    ),
    availableNow: true,
    demo: true,
  ),
  NearbyPlayer(
    'thao',
    'Thảo Vy',
    'Beginner',
    2.4,
    'assets/images/match/invite_le_thi_d_reference.png',
    'Singles',
    'Offensive',
    Offset(266, 58),
    playingArea: DiscoveryPlayingArea(
      'Son Tra playing area',
      16.0618,
      108.219,
      permitted: true,
    ),
    availableNow: true,
    demo: true,
  ),
  NearbyPlayer(
    'advanced',
    'Advanced player',
    'Advanced',
    1.8,
    'assets/images/match/host_phuc_mai_reference.png',
    '',
    '',
    Offset(45, 174),
    playingArea: DiscoveryPlayingArea(
      'Hoa Cuong playing area',
      16.0578,
      108.2108,
      permitted: true,
    ),
    availableNow: false,
    demo: true,
    listed: false,
  ),
  NearbyPlayer(
    'intermediate',
    'Intermediate player',
    'Intermediate',
    3.1,
    'assets/images/match/participant_tran_thi_b_reference.png',
    '',
    '',
    Offset(187, 202),
    playingArea: DiscoveryPlayingArea(
      'An Hai playing area',
      16.0578,
      108.219,
      permitted: true,
    ),
    availableNow: true,
    demo: true,
    listed: false,
  ),
];

class CourtPreviewData {
  const CourtPreviewData({
    this.name = 'Sky Badminton',
    this.address = '123 Lê Duẩn, Hải Châu, Đà Nẵng',
    this.photos = const ['assets/images/match/facility_court.jpg'],
  });
  final String name, address;
  final List<String> photos;
}

/// Clean model representing a badminton court facility on the map.
/// Prepares for future NestJS /facilities API integration.
class CourtLocation {
  final int id;
  final String name;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double? rating;
  final int? reviewCount;
  final String? priceRange;
  final bool? isOpen;
  final String address;
  final String? contactPhone;
  final String? description;
  final List<String> photos;
  final List<Map<String, dynamic>> courts;
  final List<Map<String, dynamic>> operatingHours;
  final List<Map<String, dynamic>> services;
  final bool demo;
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
  String get ratingText => rating == null
      ? 'No reviews yet'
      : '${rating!.toStringAsFixed(1)}${reviewCount == null ? '' : ' ($reviewCount)'}';
  String get distanceText => distanceKm == null
      ? 'Distance unavailable'
      : '${distanceKm!.toStringAsFixed(1)} km';
  double? get startingHourlyRate {
    double? result;
    for (final court in courts) {
      if (court['status'] != null && court['status'] != 'ACTIVE') continue;
      for (final slot in (court['timeSlots'] as List? ?? []).whereType<Map>()) {
        if (slot['isActive'] == false) continue;
        final hourly = slot['hourlyRate'];
        final price = slot['price'];
        double? rate;
        if (hourly is num) {
          rate = hourly.toDouble();
        } else if (price is num) {
          final start = _clockMinutes(slot['startTime']);
          final end = _clockMinutes(slot['endTime']);
          if (start != null && end != null && end > start) {
            rate = price * 60 / (end - start);
          }
        }
        if (rate != null &&
            rate.isFinite &&
            rate > 0 &&
            (result == null || rate < result)) {
          result = rate;
        }
      }
    }
    return result;
  }

  static int? _clockMinutes(Object? value) {
    final parts = value?.toString().split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 24 ||
        minute < 0 ||
        minute > 59 ||
        (hour == 24 && minute != 0)) {
      return null;
    }
    return hour * 60 + minute;
  }

  /// Facility schedules use Asia/Ho_Chi_Minh (UTC+7), independent of device zone.
  bool? isOpenAt(DateTime instant) {
    if (isOpen != null) return isOpen;
    final local = instant.toUtc().add(const Duration(hours: 7));
    final day = local.weekday % 7;
    final minute = local.hour * 60 + local.minute;
    var hasToday = false;
    for (final hours in operatingHours) {
      final start = _clockMinutes(hours['openTime']);
      final end = _clockMinutes(hours['closeTime']);
      if (start == null || end == null) continue;
      if (hours['dayOfWeek'] == day) {
        hasToday = true;
        if (end > start && minute >= start && minute < end) return true;
        if (end < start && minute >= start) return true;
      }
      if (hours['dayOfWeek'] == (day + 6) % 7 && end < start && minute < end) {
        return true;
      }
    }
    return hasToday ? false : null;
  }

  bool? get currentlyOpen => isOpenAt(DateTime.now());
  String? get discoveryPriceBand => startingHourlyRate != null
      ? (startingHourlyRate! <= 100000 ? r'$' : r'$$')
      : (priceRange == r'$' || priceRange == r'$$' ? priceRange : null);

  String? get priceSummary {
    if (priceRange != null && priceRange!.trim().isNotEmpty) {
      return priceRange;
    }
    double? minPrice;
    double? maxPrice;
    for (final court in courts) {
      if (court['status'] != null && court['status'] != 'ACTIVE') continue;
      final slots = court['timeSlots'];
      if (slots is! List) continue;
      for (final rawSlot in slots) {
        if (rawSlot is! Map) continue;
        if (rawSlot['isActive'] == false) continue;
        final hourly = rawSlot['hourlyRate'];
        final price = rawSlot['price'];
        final start = _clockMinutes(rawSlot['startTime']);
        final end = _clockMinutes(rawSlot['endTime']);
        final double? value = hourly is num
            ? hourly.toDouble()
            : price is num && start != null && end != null && end > start
            ? price * 60 / (end - start)
            : null;
        if (value != null && value.isFinite && value > 0) {
          minPrice = minPrice == null
              ? value
              : (value < minPrice ? value : minPrice);
          maxPrice = maxPrice == null
              ? value
              : (value > maxPrice ? value : maxPrice);
        }
      }
    }
    if (minPrice == null || maxPrice == null) return null;
    final minInt = minPrice.round();
    final maxInt = maxPrice.round();
    return minInt == maxInt
        ? '$minInt VND / hour'
        : '$minInt - $maxInt VND / hour';
  }

  String? get operatingHoursText {
    if (operatingHours.isEmpty) return null;
    final ranges = <String>[];
    for (final item in operatingHours) {
      final open = item['openTime']?.toString().trim();
      final close = item['closeTime']?.toString().trim();
      if (open != null &&
          open.isNotEmpty &&
          close != null &&
          close.isNotEmpty) {
        final range = '$open - $close';
        if (!ranges.contains(range)) ranges.add(range);
      }
    }
    if (ranges.isEmpty) return null;
    return ranges.first;
  }

  String get mapSubtitle =>
      [if (distanceKm != null) distanceText, ?priceSummary].join(' · ');
  String get availabilityText => currentlyOpen == null
      ? (demo ? 'Demo availability' : 'Chưa rõ giờ mở cửa')
      : currentlyOpen!
      ? 'Open now'
      : 'Closed';

  const CourtLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.rating,
    this.reviewCount,
    this.priceRange,
    this.isOpen,
    this.address = '',
    this.contactPhone,
    this.description,
    this.photos = const [],
    this.courts = const [],
    this.operatingHours = const [],
    this.services = const [],
    this.demo = false,
  });

  /// Factory for deserializing from NestJS /facilities endpoint.
  factory CourtLocation.fromJson(Map<String, dynamic> json) {
    return CourtLocation(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
      priceRange: json['priceRange'] as String?,
      isOpen: json['isOpen'] as bool?,
      address: json['address'] as String? ?? '',
      contactPhone: json['contactPhone'] as String?,
      description: json['description'] as String?,
      photos: FacilityImages.resolve(
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        photos:
            (json['photos'] as List?)?.whereType<String>().toList() ?? const [],
      ),
      courts:
          (json['courts'] as List?)
              ?.whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .toList() ??
          const [],
      services:
          (json['services'] as List?)
              ?.whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList() ??
          const [],
      operatingHours:
          (json['operatingHours'] as List?)
              ?.whereType<Map>()
              .map((h) => Map<String, dynamic>.from(h))
              .toList() ??
          const [],
    );
  }
}

/// Approved mock courts based on Figma Frame 469:1027 in Da Nang.
const mockCourts = [
  CourtLocation(
    id: 1,
    name: 'Sky Badminton',
    demo: true,
    latitude: 16.0678,
    longitude: 108.2140,
    distanceKm: 1.3,
    rating: 4.6,
    reviewCount: 128,
    priceRange: r'$',
    isOpen: true,
    address: '123 Lê Duẩn, Hải Châu, Đà Nẵng',
  ),
  CourtLocation(
    id: 2,
    name: 'VNB Court',
    demo: true,
    latitude: 16.0612,
    longitude: 108.2195,
    distanceKm: 2.1,
    rating: 4.5,
    reviewCount: 89,
    priceRange: r'$$',
    isOpen: true,
    address: '456 Phan Châu Trinh, Hải Châu, Đà Nẵng',
  ),
  CourtLocation(
    id: 3,
    name: 'Duy Tân Sport Center',
    demo: true,
    latitude: 16.0535,
    longitude: 108.2152,
    distanceKm: 3.4,
    rating: 4.8,
    reviewCount: 215,
    priceRange: r'$$',
    isOpen: false,
    address: '789 Duy Tân, Hải Châu, Đà Nẵng',
  ),
];

class ExplorationPermissionDenied implements Exception {
  const ExplorationPermissionDenied();
}

abstract class ExplorationRepository {
  Future<List<NearbyPlayer>> players();
  Future<CourtPreviewData> court();
  Future<List<CourtLocation>> courts();
}

class DemoExplorationRepository implements ExplorationRepository {
  const DemoExplorationRepository();
  @override
  Future<List<NearbyPlayer>> players() async => demoPlayers;
  @override
  Future<CourtPreviewData> court() async => const CourtPreviewData();
  @override
  Future<List<CourtLocation>> courts() async => mockCourts;
}

final explorationRepositoryProvider = Provider<ExplorationRepository>(
  (ref) => const DemoExplorationRepository(),
);

class ExplorationLocationRequired implements Exception {
  const ExplorationLocationRequired();
}

class ExplorationAccountAccessDenied implements Exception {
  const ExplorationAccountAccessDenied();
}

class ExplorationSignInRequired implements Exception {
  const ExplorationSignInRequired();
}

/// Current candidates contract has no public-location consent or availability.
/// Private latitude/longitude are deliberately discarded, not rounded or cached.
class ApiPlayerDiscoveryRepository {
  ApiPlayerDiscoveryRepository({Dio? dio, String? Function()? token})
    : dio = dio ?? ApiClient.instance.dio,
      token = token ?? (() => ApiClient.instance.token);
  final Dio dio;
  final String? Function() token;
  Future<List<NearbyPlayer>> players() async {
    final expected = token();
    if (expected == null) throw const ExplorationSignInRequired();
    try {
      final result = await dio.get(
        '/candidates/nearby',
        queryParameters: {'radiusKm': 10, 'limit': 100},
        options: Options(extra: {'expectedAuthToken': expected}),
      );
      if (token() != expected) throw const ExplorationSignInRequired();
      final data = result.data;
      if (data is! Map || data['candidates'] is! List) {
        throw const FormatException('Invalid nearby player response');
      }
      return (data['candidates'] as List).map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final distance = item['distanceKm'];
        final id = item['userId'];
        if (id is! int ||
            id <= 0 ||
            distance is! num ||
            !distance.isFinite ||
            distance < 0) {
          throw const FormatException('Invalid nearby player');
        }
        final nickname = item['nickname'];
        final name = nickname is String && nickname.trim().isNotEmpty
            ? nickname.trim()
            : item['fullName'];
        return NearbyPlayer(
          '$id',
          name is String && name.trim().isNotEmpty ? name : 'Player #$id',
          switch (item['skillLevel']?.toString().toUpperCase()) {
            'BEGINNER' => 'Beginner',
            'INTERMEDIATE' => 'Intermediate',
            'ADVANCED' => 'Advanced',
            _ => 'Not assessed',
          },
          distance.toDouble(),
          '',
          '',
          '',
          Offset.zero,
        );
      }).toList();
    } on DioException catch (error) {
      if (error.response?.statusCode == 400) {
        throw const ExplorationLocationRequired();
      }
      if (error.response?.statusCode == 401) {
        throw const ExplorationSignInRequired();
      }
      if (error.response?.statusCode == 403) {
        throw const ExplorationAccountAccessDenied();
      }
      rethrow;
    }
  }
}

final apiPlayerDiscoveryRepositoryProvider =
    Provider<ApiPlayerDiscoveryRepository>(
      (ref) => ApiPlayerDiscoveryRepository(),
    );
final nearbyPlayersProvider = FutureProvider.autoDispose<List<NearbyPlayer>>(
  (ref) => ref.watch(apiPlayerDiscoveryRepositoryProvider).players(),
);
final courtPreviewProvider = FutureProvider<CourtPreviewData>(
  (ref) => ref.watch(explorationRepositoryProvider).court(),
);
final facilityDetailProvider = FutureProvider.autoDispose
    .family<CourtLocation, int>((ref, id) async {
      final response = await ApiClient.instance.dio.get('/facilities/$id');
      final location = CourtLocation.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      if (location.id != id) {
        throw const FormatException('Facility identity mismatch');
      }
      return location;
    });
final nearbyCourtsProvider = FutureProvider.autoDispose<List<CourtLocation>>((
  ref,
) async {
  final response = await ApiClient.instance.dio.get('/facilities');
  final data = response.data;
  if (data is! List) {
    throw const FormatException('Invalid facilities response');
  }
  return data
      .whereType<Map>()
      .map((item) => CourtLocation.fromJson(Map<String, dynamic>.from(item)))
      .where((court) => !court.demo && court.id > 0)
      .toList();
});

// Retain only the schematic transform across mode changes, never GPS coordinates.
final playerMapCameraProvider = StateProvider<Matrix4>(
  (ref) => Matrix4.identity(),
);
