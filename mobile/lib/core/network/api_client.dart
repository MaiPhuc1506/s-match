import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._internal();
  late final Dio dio;
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;

  String? get token => _token;
  String? get refreshToken => _refreshToken;

  void setToken(String? token, {String? refreshToken}) {
    _token = token;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }
  }

  void clearToken() {
    _token = null;
    _refreshToken = null;
  }

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
          // Mutations tied to a screen/account must not adopt a newer account's
          // token while waiting in Dio's request interceptor queue.
          final expected = options.extra['expectedAuthToken'];
          if (expected != null && expected != _token) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Authentication session changed.',
              ),
            );
            return;
          }
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (err, handler) async {
          final isAuthEndpoint = err.requestOptions.path.startsWith('/auth/');
          final alreadyRetried = err.requestOptions.extra['authRetried'] == true;
          if (err.response?.statusCode == 401 &&
              !isAuthEndpoint &&
              !alreadyRetried &&
              _refreshToken != null) {
            final refreshed = await tryRefreshSession();
            if (refreshed && _token != null) {
              final opts = err.requestOptions;
              opts.extra['authRetried'] = true;
              opts.headers['Authorization'] = 'Bearer $_token';
              try {
                final retryRes = await dio.fetch<dynamic>(opts);
                return handler.resolve(retryRes);
              } on DioException catch (retryErr) {
                return handler.next(retryErr);
              }
            }
          }
          return handler.next(err);
        },
      ),
    );
  }

  Future<bool> tryRefreshSession() async {
    final rt = _refreshToken;
    if (rt == null || rt.trim().isEmpty) return false;
    if (_refreshInFlight != null) return _refreshInFlight!;

    final future = () async {
      try {
        final res = await dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': rt},
        );
        final newAccess = res.data?['accessToken'] as String?;
        final newRefresh = res.data?['refreshToken'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          _token = newAccess;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
          }
          return true;
        }
      } catch (_) {}
      return false;
    }();

    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
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
      final user = res.data['user'];
      if (user is Map<String, dynamic>) {
        // Đồng bộ thông tin user hiện tại nếu AuthService chưa có
        // Cần import AuthService hoặc truy cập qua AuthService.instance
      }
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
