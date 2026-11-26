import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Live Open Match endpoints; no local match state is substituted on errors.
class OpenMatchService {
  OpenMatchService({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;
  final Dio _dio;
  Future<List<Map<String, dynamic>>> list({
    Map<String, dynamic>? filters,
  }) async {
    final response = await _dio.get('/open-matches', queryParameters: filters);
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> mine() async {
    final response = await _dio.get('/matches/mine');
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final response = await _dio.get('/matches/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> request(int id) async => _dio.post('/open-matches/$id/join');
  Future<void> invitation(int id, bool accept) async =>
      _dio.patch('/matches/$id/invitations/${accept ? 'accept' : 'reject'}');
  Future<void> leave(int id) async => _dio.patch('/open-matches/$id/leave');
  Future<void> cancel(int id) async => _dio.patch('/matches/$id/cancel');
  Future<void> complete(int id) async => _dio.patch('/matches/$id/complete');
  Future<void> respond(
    int matchId,
    int participantId,
    bool accept,
  ) async => _dio.patch(
    '/open-matches/$matchId/participants/$participantId/${accept ? 'accept' : 'reject'}',
  );
  Future<Map<String, dynamic>> create({
    required int bookingId,
    required String mode,
    required int capacity,
    required int minSkill,
    required int maxSkill,
    String? description,
  }) async {
    final response = await _dio.post(
      '/bookings/$bookingId/open-match',
      data: {
        'mode': mode,
        'purpose': 'CASUAL',
        'neededPlayers': capacity - 1,
        'minSkillLevel': minSkill,
        'maxSkillLevel': maxSkill,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
