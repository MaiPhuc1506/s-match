import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit, replaceable UI fixtures: no coordinates or API contracts are implied.
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
  });
  final String id, name, level, avatar, mode, style;
  final double distance;
  final Offset marker;
  final bool listed;
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

class ExplorationPermissionDenied implements Exception {
  const ExplorationPermissionDenied();
}

abstract class ExplorationRepository {
  Future<List<NearbyPlayer>> players();
  Future<CourtPreviewData> court();
}

class DemoExplorationRepository implements ExplorationRepository {
  const DemoExplorationRepository();
  @override
  Future<List<NearbyPlayer>> players() async => demoPlayers;
  @override
  Future<CourtPreviewData> court() async => const CourtPreviewData();
}

final explorationRepositoryProvider = Provider<ExplorationRepository>(
  (ref) => const DemoExplorationRepository(),
);
final nearbyPlayersProvider = FutureProvider<List<NearbyPlayer>>(
  (ref) => ref.watch(explorationRepositoryProvider).players(),
);
final courtPreviewProvider = FutureProvider<CourtPreviewData>(
  (ref) => ref.watch(explorationRepositoryProvider).court(),
);

// Retain only the schematic transform across mode changes, never GPS coordinates.
final playerMapCameraProvider = StateProvider<Matrix4>(
  (ref) => Matrix4.identity(),
);
