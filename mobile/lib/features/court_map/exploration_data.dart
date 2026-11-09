import '../../core/network/api_client.dart';

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
  final List<String> photos;
  final List<Map<String, dynamic>> courts;
  final bool demo;
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
  String get ratingText => rating == null
      ? (demo ? 'No reviews yet' : 'Chưa có đánh giá')
      : '${rating!.toStringAsFixed(1)}${reviewCount == null ? '' : ' ($reviewCount)'}';
  String get distanceText => distanceKm == null
      ? (demo ? 'Distance unavailable' : 'Chưa có khoảng cách')
      : '${distanceKm!.toStringAsFixed(1)} km';
  String get mapSubtitle =>
      [if (distanceKm != null) distanceText, ?priceRange].join(' · ');
  String get availabilityText => isOpen == null
      ? (demo ? 'Demo availability' : 'Chưa rõ giờ mở cửa')
      : isOpen!
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
    this.photos = const [],
    this.courts = const [],
    this.demo = false,
  });

  /// Factory for deserializing from future NestJS /facilities endpoint.
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
      photos:
          (json['photos'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      courts:
          (json['courts'] as List?)
              ?.whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
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
            _ => 'Level not shared',
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
final nearbyCourtsProvider = FutureProvider.autoDispose<List<CourtLocation>>((
  ref,
) async {
  final response = await ApiClient.instance.dio.get('/facilities');
  return (response.data as List)
      .map(
        (item) =>
            CourtLocation.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
});

// Retain only the schematic transform across mode changes, never GPS coordinates.
final playerMapCameraProvider = StateProvider<Matrix4>(
  (ref) => Matrix4.identity(),
);
