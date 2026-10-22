/// Public recommendation data; absent API fields remain absent, never inferred.
class RecommendedPlayer {
  const RecommendedPlayer({
    required this.id,
    required this.score,
    this.name,
    this.level,
    this.distanceKm,
    this.avatarAsset,
    this.avatarUrl,
    this.reasons = const [],
    this.bio,
    this.location,
    this.mode,
    this.playStyle,
    this.availability,
    this.matches,
    this.completed,
    this.rating,
    this.hasReferenceRadar = false,
  });
  final String id;
  final double score;
  final String? name, level, avatarAsset, avatarUrl, bio, location;
  final String? mode, playStyle, availability;
  final double? distanceKm, rating;
  final int? matches, completed;
  final List<String> reasons;
  // Static reference radar is confined to the explicit UI fixture repository.
  final bool hasReferenceRadar;
  String get displayName => name ?? 'Player #$id';
}

class RecommendationQuery {
  const RecommendationQuery({this.distanceKm = 5, this.level, this.style});
  final double distanceKm;
  final String? level, style;
}
