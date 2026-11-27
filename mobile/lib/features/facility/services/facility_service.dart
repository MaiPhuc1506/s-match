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
      final token = _client.token;
      if (token == null) return null;
      final res = await _client.dio.get('/facilities/my', options: Options(extra: {'expectedAuthToken': token}));
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

  /// Tạo cơ sở (cụm sân) thể thao mới
  Future<Map<String, dynamic>?> createFacility({
    required String name,
    required String address,
    String? contactPhone,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = _client.token;
      if (token == null) {
        debugPrint('[CREATE FACILITY] Không có token chủ sân hợp lệ.');
        return null;
      }
      final res = await _client.dio.post(
        '/facilities',
        options: Options(extra: {'expectedAuthToken': token}),
        data: {
          'name': name,
          'address': address,
          if (contactPhone != null && contactPhone.isNotEmpty)
            'contactPhone': contactPhone,
          if (description != null && description.isNotEmpty)
            'description': description,
          ...?latitude != null ? {'latitude': latitude} : null,
          ...?longitude != null ? {'longitude': longitude} : null,
        },
      );
      return res.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint(
        '[CREATE FACILITY ERROR] ${e.response?.statusCode}: ${e.response?.data}',
      );
      return null;
    } catch (e) {
      debugPrint('[CREATE FACILITY ERROR] Lỗi: $e');
      return null;
    }
  }

  /// Cập nhật thông tin cơ sở
  Future<bool> updateFacility({
    required int facilityId,
    required String name,
    required String address,
    String? contactPhone,
    String? description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final token = _client.token;
      if (token == null) return false;
      final res = await _client.dio.patch(
        '/facilities/$facilityId',
        options: Options(extra: {'expectedAuthToken': token}),
        data: {
          'name': name,
          'address': address,
          ...?contactPhone != null ? {'contactPhone': contactPhone} : null,
          ...?description != null ? {'description': description} : null,
          ...?latitude != null ? {'latitude': latitude} : null,
          ...?longitude != null ? {'longitude': longitude} : null,
        },
      );
      return res.statusCode == 200;
    } on DioException catch (e) {
      debugPrint(
        '[UPDATE FACILITY ERROR] ${e.response?.statusCode}: ${e.response?.data}',
      );
      return false;
    } catch (e) {
      debugPrint('[UPDATE FACILITY ERROR] Lỗi: $e');
      return false;
    }
  }

  /// Xóa cơ sở (cascade xóa tất cả sân con)
  Future<({bool success, String? message})> deleteFacility(
    int facilityId,
  ) async {
    try {
      final token = _client.token;
      if (token == null) {
        return (
          success: false,
          message: 'Sign in again to manage your facilities.',
        );
      }
      final res = await _client.dio.delete('/facilities/$facilityId', options: Options(extra: {'expectedAuthToken': token}));
      if (res.statusCode == 200 || res.statusCode == 204) {
        return (success: true, message: null);
      }
      return (
        success: false,
        message: 'Could not delete this facility. Please try again.',
      );
    } on DioException catch (e) {
      String? errorMsg;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'];
        if (msg is List) {
          errorMsg = msg.join(', ');
        } else if (msg is String) {
          errorMsg = msg;
        }
      }
      errorMsg ??= (e.response?.statusCode == 403
          ? 'Only the owner can delete this facility.'
          : e.response?.statusCode == 404
          ? 'Facility not found.'
          : 'Could not delete this facility. Please try again.');
      debugPrint('[DELETE FACILITY ERROR] $errorMsg');
      return (success: false, message: errorMsg);
    } catch (e) {
      debugPrint('[DELETE FACILITY ERROR] Lỗi: $e');
      return (success: false, message: 'Could not delete this facility. Please try again.');
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
      final token = _client.token;
      if (token == null) {
        debugPrint('[ADD COURT] Không có token chủ sân hợp lệ.');
        return false;
      }
      final res = await _client.dio.post(
        '/facilities/$facilityId/courts',
        options: Options(extra: {'expectedAuthToken': token}),
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
      final token = _client.token;
      if (token == null) return false;
      final res = await _client.dio.patch(
        '/facilities/$facilityId/courts/$courtId',
        options: Options(extra: {'expectedAuthToken': token}),
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
      final token = _client.token;
      if (token == null) return false;
      final res = await _client.dio.patch(
        '/facilities/$facilityId/courts/$courtId/time-slots/$slotId',
        options: Options(extra: {'expectedAuthToken': token}),
        data: {'isActive': isActive},
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi khóa/mở khung giờ: $e');
      return false;
    }
  }

  Future<bool> updateTimeSlotPrice({
    required int facilityId,
    required int courtId,
    required int slotId,
    required double price,
  }) async {
    try {
      final token = _client.token;
      if (token == null) return false;
      final response = await _client.dio.patch(
        '/facilities/$facilityId/courts/$courtId/time-slots/$slotId/pricing',
        options: Options(extra: {'expectedAuthToken': token}),
        data: {'price': price},
      );
      return _client.token == token && response.statusCode == 200;
    } catch (e) {
      debugPrint('Lỗi cập nhật giá khung giờ: $e');
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
      final token = _client.token;
      if (token == null) return false;
      final res = await _client.dio.post(
        '/facilities/$facilityId/courts/$courtId/time-slots',
        options: Options(extra: {'expectedAuthToken': token}),
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
      final token = _client.token;
      if (token == null) {
        debugPrint('[UPDATE HOURS] Không có token chủ sân hợp lệ.');
        return false;
      }
      final res = await _client.dio.put(
        '/facilities/$facilityId/operating-hours/bulk',
        options: Options(extra: {'expectedAuthToken': token}),
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
