import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;
  String? _token;

  ApiClient._internal() {
    // Tự động nhận diện môi trường:
    // Android Emulator dùng 10.0.2.2, iOS Simulator / macOS dùng localhost
    final baseUrl = Platform.isAndroid
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Tự động gắn token vào mỗi request nếu đã có token
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Đăng nhập bằng tài khoản Demo Court Owner đã có sẵn trong Seed
  Future<String?> ensureOwnerToken() async {
    if (_token != null) return _token;
    try {
      final res = await dio.post(
        '/auth/login',
        data: {'email': 'owner@smatch.dev', 'password': 'Password123!'},
      );
      _token = res.data['accessToken'];
      return _token;
    } on DioException catch (e) {
      debugPrint(
        '[AUTH ERROR] Đăng nhập chủ sân thất bại: ${e.response?.statusCode} - ${e.response?.data}',
      );
      return null;
    } catch (e) {
      debugPrint('[AUTH ERROR] Lỗi không xác định: $e');
      return null;
    }
  }
}
