import '../models/recommended_player.dart';
import 'recommendation_repository.dart';

/// Approved Figma placeholders. Never used as a fallback for API errors.
class FixtureRecommendationRepository extends RecommendationRepository {
  const FixtureRecommendationRepository();
  @override
  bool get isPreview => true;
  @override
  Future<List<RecommendedPlayer>> search(RecommendationQuery query) async =>
      referenceRecommendations;
}

final referenceRecommendations = List<RecommendedPlayer>.generate(8, (index) {
  const names = [
    'Nguyễn Minh Anh',
    'Trần Thu Hà',
    'Lê Quốc Bảo',
    'Phạm Gia Huy',
    'Nguyễn Thảo Vy',
    'Lê Minh Quân',
    'Trần Hoàng Nam',
    'Phạm Ngọc Anh',
  ];
  const scores = [94.0, 89.0, 86.0, 83.0, 81.0, 80.0, 78.0, 76.0];
  const distances = [1.2, 2.4, 3.1, 3.8, 2.8, 4.2, 4.5, 4.8];
  const portraits = [
    'host_nguyen_van_a_reference.png',
    'invite_le_thi_d_reference.png',
    'host_phuc_mai_reference.png',
    'host_phuc_mai_reference.png',
    'participant_tran_thi_b_reference.png',
    'host_nguyen_van_a_reference.png',
    'host_phuc_mai_reference.png',
    'invite_le_thi_d_reference.png',
  ];
  const reasons = [
    ['Similar skill level', 'Available at your preferred time', 'Lives nearby'],
    ['Similar play style', 'Available this week', 'Good match for doubles'],
    ['Similar skill level', 'Available on weekends', 'Lives nearby'],
    ['Prefers doubles', 'Available in the evening', 'Similar play style'],
    ['Available this week', 'Prefers doubles', 'Lives nearby'],
    ['Similar skill level', 'Balanced play style', 'Available on weekends'],
    ['Prefers doubles', 'Available in the evening', 'Lives nearby'],
    ['Similar skill level', 'Available this week', 'Similar play style'],
  ];
  return RecommendedPlayer(
    id: 'reference-$index',
    name: names[index],
    score: scores[index],
    level: index == 2 || index == 6
        ? 'Advanced'
        : index == 4
        ? 'Beginner'
        : 'Intermediate',
    distanceKm: distances[index],
    avatarAsset: 'assets/images/match/${portraits[index]}',
    reasons: reasons[index],
    bio: 'Casual doubles player. Available on weekday evenings and weekends.',
    location: 'Da Nang, Vietnam',
    mode: 'Doubles',
    playStyle: 'Offensive',
    availability: 'Weekday evenings\nWeekends (all day)',
    matches: 32,
    completed: 26,
    rating: 4.7,
    hasReferenceRadar: true,
  );
});
