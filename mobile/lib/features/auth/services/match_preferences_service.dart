import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class MatchPreferencesFailure implements Exception {
  const MatchPreferencesFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// API contract adapter. Playing style and Both are not supported by the
/// backend preference DTO; neither is silently converted into another value.
class MatchPreferencesService {
  MatchPreferencesService._();
  static final instance = MatchPreferencesService._();
  final _client = ApiClient.instance;
  Future<
    ({
      Map<String, dynamic>? preference,
      List<Map<String, dynamic>> availability,
    })
  >
  load() async {
    final session = _client.token;
    try {
      final pref = (await _client.dio.get('/preferences/me')).data;
      _guard(session);
      final slots = (await _client.dio.get('/availability/me')).data;
      _guard(session);
      if ((pref != null && pref is! Map) || slots is! List) {
        throw const MatchPreferencesFailure(
          'The saved preferences response is invalid.',
        );
      }
      return (
        preference: pref == null ? null : Map<String, dynamic>.from(pref),
        availability: slots
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList(),
      );
    } on DioException catch (e) {
      throw MatchPreferencesFailure(_message(e));
    }
  }

  Future<void> save({
    required String mode,
    required int minLevel,
    required int maxLevel,
    required Set<int> days,
    required String from,
    required String to,
    required Map<String, dynamic>? existingPreference,
    required List<Map<String, dynamic>> existingAvailability,
  }) async {
    if (_client.token == null) {
      throw const MatchPreferencesFailure('Sign in to save preferences.');
    }
    if (mode == 'Both') {
      throw const MatchPreferencesFailure(
        'The current API supports Singles or Doubles. Both is available in UI preview only.',
      );
    }
    final seen = <int>{};
    if (existingAvailability.any((s) => !seen.add(s['dayOfWeek'] as int))) {
      throw const MatchPreferencesFailure(
        'Your saved schedule has multiple windows per day. This form cannot replace them safely yet.',
      );
    }
    final session = _client.token;
    try {
      _guard(session);
      await _client.dio.put(
        '/preferences/me',
        data: {
          'preferredMode': mode.toUpperCase(),
          'purpose': existingPreference?['purpose'] ?? 'CASUAL',
          'minSkillLevel': minLevel,
          'maxSkillLevel': maxLevel,
          'maxDistanceKm': existingPreference?['maxDistanceKm'] ?? 5,
        },
      );
      for (final day in days) {
        _guard(session);
        final matches = existingAvailability.where(
          (s) => s['dayOfWeek'] == day,
        );
        final body = {'dayOfWeek': day, 'startTime': from, 'endTime': to};
        if (matches.isEmpty) {
          await _client.dio.post('/availability/me', data: body);
        } else {
          await _client.dio.patch(
            '/availability/me/${matches.first['id']}',
            data: body,
          );
        }
      }
      for (final old in existingAvailability.where(
        (s) => !days.contains(s['dayOfWeek']),
      )) {
        _guard(session);
        await _client.dio.delete('/availability/me/${old['id']}');
      }
    } on DioException catch (e) {
      throw MatchPreferencesFailure(
        '${_message(e)} Some changes may have been saved; reload before retrying.',
      );
    }
  }

  void _guard(String? token) {
    if (token == null || token != _client.token) {
      throw const MatchPreferencesFailure(
        'Your session changed. Reopen preferences before continuing.',
      );
    }
  }

  String _message(DioException e) => switch (e.response?.statusCode) {
    401 => 'Your session has expired. Please sign in again.',
    403 => 'Only Player accounts can edit these preferences.',
    _ => 'Unable to save or load preferences. Please try again.',
  };
}

/// Anonymous UI preview state, never submitted to a backend under another user.
class MatchPreferencesPreview {
  static Set<String> days = {'Mon', 'Wed', 'Fri'};
  static String from = '18:00',
      to = '22:00',
      mode = 'Doubles',
      level = 'Intermediate',
      style = 'Balanced';
}
