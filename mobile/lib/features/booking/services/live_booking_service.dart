import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

/// Uses the existing facility/time-slot and booking contracts.
class LiveBookingService {
  LiveBookingService({Dio? dio, String? Function()? token})
    : _dio = dio ?? ApiClient.instance.dio,
      _token = token ?? (() => ApiClient.instance.token);
  final Dio _dio;
  final String? Function() _token;

  Future<Map<String, dynamic>> facility(int id) async {
    final response = await _dio.get('/facilities/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async {
    final response = await _dio.get(
      '/facilities/$facilityId/courts/$courtId/time-slots/availability',
      queryParameters: {'date': date},
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> book({
    required int courtId,
    required String startTime,
    required String endTime,
  }) async {
    final token = _token();
    if (token == null) throw StateError('Vui lòng đăng nhập để đặt sân.');
    final response = await _dio.post(
      '/bookings',
      options: Options(extra: {'expectedAuthToken': token}),
      data: {'courtId': courtId, 'startTime': startTime, 'endTime': endTime},
    );
    if (_token() != token) {
      throw StateError(
        'Phiên đăng nhập đã thay đổi. Vui lòng mở lại lịch sử đặt sân.',
      );
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}
