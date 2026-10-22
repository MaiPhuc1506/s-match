import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/recommended_player.dart';
import 'recommendation_fixtures.dart';

abstract class RecommendationRepository {
  const RecommendationRepository();
  Future<List<RecommendedPlayer>> search(RecommendationQuery query);
  bool get isPreview => false;
}

class RecommendationFailure implements Exception {
  const RecommendationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiRecommendationRepository extends RecommendationRepository {
  ApiRecommendationRepository(this.dio);
  final Dio dio;

  static String? _displayText(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  @override
  Future<List<RecommendedPlayer>> search(RecommendationQuery query) async {
    try {
      // Use actual saved location/availability, not the schematic Map's fixtures.
      final me = (await dio.get<Map<String, dynamic>>('/players/profile/me'))
          .data!;
      final rawProfile = me['playerProfile'];
      final profile = rawProfile is Map
          ? Map<String, dynamic>.from(rawProfile)
          : null;
      final latitude = profile?['latitude'], longitude = profile?['longitude'];
      if (latitude is! num || longitude is! num) {
        throw const RecommendationFailure(
          'Save your location before searching for players.',
        );
      }
      final slots =
          (await dio.get<List<dynamic>>(
            '/availability/${me['id']}/upcoming-slots',
            queryParameters: {'days': 7},
          )).data ??
          [];
      if (slots.isEmpty) {
        throw const RecommendationFailure(
          'Add upcoming availability before searching for players.',
        );
      }
      final bounds = switch (query.level) {
        'Beginner' => (1, 2),
        'Intermediate' => (3, 4),
        'Advanced' => (5, 5),
        _ => null,
      };
      final style = switch (query.style) {
        'Offensive' => 'Attack',
        'Defensive' => 'Defense',
        'Balanced' => 'Balanced',
        _ => null,
      };
      final response = await dio.post<Map<String, dynamic>>(
        '/matchmaking/recommend',
        data: {
          'availableTimeSlots': slots,
          'location': {'latitude': latitude, 'longitude': longitude},
          'maxDistanceKm': query.distanceKm,
          if (bounds != null) 'minSkillLevel': bounds.$1,
          if (bounds != null) 'maxSkillLevel': bounds.$2,
          if (style != null) 'playingStyles': [style],
        },
      );
      final matches = response.data?['matchedUsers'];
      if (matches is! List) {
        throw const FormatException('Invalid recommendation response');
      }
      if (matches.isEmpty) return [];
      // Nearby only supplements distance; display identity comes from the ranked
      // response so its independent radius/limit cannot hide player profiles.
      final candidates = <String, Map<String, dynamic>>{};
      try {
        final nearby = await dio.get<Map<String, dynamic>>(
          '/candidates/nearby',
          queryParameters: {'radiusKm': query.distanceKm, 'limit': 100},
        );
        for (final row in (nearby.data?['candidates'] as List? ?? [])) {
          final candidate = Map<String, dynamic>.from(row as Map);
          candidates['${candidate['userId']}'] = candidate;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          rethrow;
        }
        // Scores remain usable when optional public metadata is unavailable.
      }
      return matches
          .map((row) {
            final m = Map<String, dynamic>.from(row as Map);
            final id = m['userId'];
            final score = m['matchScore'];
            if (id is! String ||
                id.isEmpty ||
                score is! num ||
                !score.isFinite ||
                score < 0 ||
                score > 100) {
              throw const FormatException('Invalid recommendation score');
            }
            final rawPublicProfile = m['profile'];
            final publicProfile = rawPublicProfile is Map
                ? Map<String, dynamic>.from(rawPublicProfile)
                : <String, dynamic>{};
            final c = candidates[id];
            return RecommendedPlayer(
              id: id,
              score: score.toDouble(),
              name:
                  _displayText(publicProfile['nickname']) ??
                  _displayText(publicProfile['fullName']),
              level: _displayText(publicProfile['skillLevel']),
              avatarUrl: _displayText(publicProfile['avatarUrl']),
              distanceKm: (c?['distanceKm'] as num?)?.toDouble(),
            );
          })
          .toList(growable: false);
    } on RecommendationFailure {
      rethrow;
    } on DioException catch (e) {
      throw RecommendationFailure(switch (e.response?.statusCode) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Recommendations are available to Player accounts only.',
        400 =>
          'Check your saved location, availability and search preferences.',
        _ => 'Unable to load recommendations. Please try again.',
      });
    } on FormatException {
      throw const RecommendationFailure(
        'The recommendation response is invalid. Please try again.',
      );
    }
  }
}

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  const preview = bool.fromEnvironment('SPRINT7_USE_MOCKS');
  if (kDebugMode && preview) return const FixtureRecommendationRepository();
  return ApiRecommendationRepository(ApiClient.instance.dio);
});

final recommendationsProvider = FutureProvider.autoDispose
    .family<List<RecommendedPlayer>, RecommendationQuery>(
      (ref, query) => ref.watch(recommendationRepositoryProvider).search(query),
    );
