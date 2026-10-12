import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:mobile/core/network/api_client.dart';

class FacilityService {
  static final FacilityService instance = FacilityService._internal();
  FacilityService._internal();

  final _client = ApiClient.instance;

  Future<List<Map<String, dynamic>>?> getPublicFacilities() async {
    try {
      final res = await _client.dio.get('/facilities');
      return (res.data as List)
          .map((facility) => Map<String, dynamic>.from(facility as Map))
          .toList();
    } catch (e) {
      debugPrint('Lỗi lấy danh sách cơ sở công khai: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getMyFacilities() async {
    try {
      if (await _client.ensureOwnerToken() == null) return null;
      final res = await _client.dio.get('/facilities/my');
      return (res.data as List)
          .map((facility) => Map<String, dynamic>.from(facility as Map))
          .toList();
    } catch (e) {
      debugPrint('Lỗi lấy danh sách cơ sở: $e');
      return null;
    }
  }

  /// 1. Lấy chi tiết cơ sở (bao gồm danh sách sân con và giờ hoạt động)
  Future<Map<String, dynamic>?> getFacilityDetails(int facilityId) async {
    try {
      final res = await _client.dio.get('/facilities/$facilityId');
      return res.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Lỗi lấy thông tin cơ sở: $e');
      return null;
    }
  }

  /// 2. Thêm sân con mới vào Database (SMM-14)
  Future<bool> addCourt({
    required int facilityId,
    required String name,
    required String courtType,
    required String status,
  }) async {
    try {
      final token = await _client.ensureOwnerToken();
      if (token == null) {
        debugPrint('[ADD COURT] Không có token chủ sân hợp lệ.');
        return false;
      }
      final res = await _client.dio.post(
        '/facilities/$facilityId/courts',
        data: {
          'name': name,
          'courtType': courtType.toUpperCase(), // INDOOR hoặc OUTDOOR
          'status': status.toUpperCase(), // ACTIVE, MAINTENANCE, INACTIVE
        },
      );
      return res.statusCode == 201;
    } on DioException catch (e) {
      debugPrint(
        '[ADD COURT ERROR] ${e.response?.statusCode}: ${e.response?.data}',
      );
      return false;
    } catch (e) {
      debugPrint('[ADD COURT ERROR] Lỗi: $e');
      return false;
    }
  }

  Future<bool> updateCourt({
    required int facilityId,
    required int courtId,
    required String name,
    required String courtType,
    required String status,
  }) async {
    try {
      if (await _client.ensureOwnerToken() == null) return false;
      final res = await _client.dio.patch(
        '/facilities/$facilityId/courts/$courtId',
        data: {
          'name': name,
          'courtType': courtType.toUpperCase(),
          'status': status,
        },
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi cập nhật sân: $e');
      return false;
    }
  }

  Future<bool> setTimeSlotActive({
    required int facilityId,
    required int courtId,
    required int slotId,
    required bool isActive,
  }) async {
    try {
      if (await _client.ensureOwnerToken() == null) return false;
      final res = await _client.dio.patch(
        '/facilities/$facilityId/courts/$courtId/time-slots/$slotId',
        data: {'isActive': isActive},
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi khóa/mở khung giờ: $e');
      return false;
    }
  }

  Future<bool> addTimeSlot({
    required int facilityId,
    required int courtId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required double price,
  }) async {
    try {
      if (await _client.ensureOwnerToken() == null) return false;
      final res = await _client.dio.post(
        '/facilities/$facilityId/courts/$courtId/time-slots',
        data: {
          'dayOfWeek': dayOfWeek,
          'startTime': startTime,
          'endTime': endTime,
          'price': price,
        },
      );
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('Lỗi thêm khung giờ: $e');
      return false;
    }
  }

  /// 3. Cập nhật giờ hoạt động của cơ sở vào Database (SMM-16)
  Future<bool> updateOperatingHours({
    required int facilityId,
    required List<Map<String, dynamic>> days,
  }) async {
    try {
      final token = await _client.ensureOwnerToken();
      if (token == null) {
        debugPrint('[UPDATE HOURS] Không có token chủ sân hợp lệ.');
        return false;
      }
      final res = await _client.dio.put(
        '/facilities/$facilityId/operating-hours/bulk',
        data: {'days': days},
      );
      return res.statusCode == 200;
    } on DioException catch (e) {
      debugPrint(
        '[UPDATE HOURS ERROR] ${e.response?.statusCode}: ${e.response?.data}',
      );
      return false;
    } catch (e) {
      debugPrint('[UPDATE HOURS ERROR] Lỗi: $e');
      return false;
    }
  }
}
