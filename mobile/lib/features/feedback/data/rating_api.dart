import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../auth/services/auth_service.dart';

class RatingFailure implements Exception {
  const RatingFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Invalidates visible profile summaries after a successful server write.
final ratingRevision = ValueNotifier<int>(0);

class RatingSummary {
  const RatingSummary({
    required this.count,
    this.average,
    required this.distribution,
    this.reliability,
  });
  final int count;
  final double? average, reliability;
  final Map<int, int> distribution;
  String get label => average?.toStringAsFixed(1) ?? '—';
  factory RatingSummary.fromJson(Map<String, dynamic> json) => RatingSummary(
    count: (json['ratingCount'] as num).toInt(),
    average: (json['communityRating'] as num?)?.toDouble(),
    reliability: (json['reliabilityScore'] as num?)?.toDouble(),
    distribution: {
      for (var i = 1; i <= 5; i++)
        i: ((json['distribution'] as Map?)?['$i'] as num?)?.toInt() ?? 0,
    },
  );
}

/// Uses the SMM-36 rating contract for both writes and reads. No second POST to
/// SMM-34 Feedback: these are separate stores, not interchangeable endpoints.
class RatingApi {
  RatingApi({required this.userId, required this.token});
  factory RatingApi.current() => RatingApi(
    userId: (AuthService.instance.currentUser?['id'] as num?)?.toInt() ?? 0,
    token: ApiClient.instance.token ?? '',
  );
  final int userId;
  final String token;
  final _client = ApiClient.instance;
  void checkSession() {
    if (userId <= 0 || token.isEmpty || token != _client.token) {
      throw const RatingFailure(
        'Your session changed. Sign in and reopen this screen.',
      );
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
  }) async {
    checkSession();
    try {
      final response = await _client.dio.request<dynamic>(
        path,
        data: data,
        options: Options(method: method, extra: {'expectedAuthToken': token}),
      );
      checkSession();
      return response.data;
    } on DioException catch (error) {
      checkSession();
      final message = switch (error.response?.statusCode) {
        401 => 'Your session expired. Please sign in again.',
        403 => 'You do not have permission to rate this match.',
        404 => 'Match or player not found.',
        409 => 'Already submitted or the match state changed. Refresh before retrying.',
        _ => 'Unable to load or save ratings. Please try again.',
      };
      final body = error.response?.data;
      final detail = body is Map ? body['message'] : null;
      throw RatingFailure(
        error.response?.statusCode == 400 && detail is String
            ? detail
            : message,
      );
    }
  }

  Future<RatingSummary> summary(int targetId) async => RatingSummary.fromJson(
    Map<String, dynamic>.from(
      await request('/ratings/users/$targetId/summary') as Map,
    ),
  );
  Future<List<Map<String, dynamic>>> ratings({
    required bool given,
    int? targetId,
  }) async {
    final path = given
        ? '/ratings/given'
        : '/ratings/users/${targetId ?? userId}';
    final rows = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final data = await request('$path?page=$page&limit=50') as Map;
      rows.addAll(
        (data['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (page >= (data['totalPages'] as num).toInt()) break;
    }
    return rows;
  }
}
