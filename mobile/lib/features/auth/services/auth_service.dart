import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? user;
  final String? accessToken;

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.accessToken,
  });

  factory AuthResult.success({
    Map<String, dynamic>? user,
    String? accessToken,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      accessToken: accessToken,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult._(
      isSuccess: false,
      errorMessage: errorMessage,
    );
  }
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final _client = ApiClient.instance;

  Map<String, dynamic>? currentUser;
  String? _refreshToken;
  String? get refreshToken => _refreshToken;

  /// Đăng nhập bằng Email và Password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (accessToken != null) {
          _client.setToken(accessToken);
          _refreshToken = refreshToken;
          currentUser = user;
        }

        return AuthResult.success(
          user: user,
          accessToken: accessToken,
        );
      }
      return AuthResult.failure('Đăng nhập thất bại.');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is List) {
          return AuthResult.failure(message.join(', '));
        } else if (message is String) {
          return AuthResult.failure(message);
        }
      }
      return AuthResult.failure(
        e.response?.statusCode == 401
            ? 'Sai email hoặc mật khẩu'
            : 'Không thể kết nối đến máy chủ (${e.message})',
      );
    } catch (e) {
      return AuthResult.failure('Đã xảy ra lỗi: $e');
    }
  }

  /// Đăng ký tài khoản mới
  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/register',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'fullName': fullName.trim(),
          if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            'phoneNumber': phoneNumber.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final user = data['data'] as Map<String, dynamic>?;
        return AuthResult.success(user: user);
      }
      return AuthResult.failure('Đăng ký thất bại.');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is List) {
          return AuthResult.failure(message.join(', '));
        } else if (message is String) {
          return AuthResult.failure(message);
        }
      }
      return AuthResult.failure(
        e.response?.statusCode == 400
            ? 'Email đã được sử dụng hoặc dữ liệu không hợp lệ'
            : 'Không thể kết nối đến máy chủ (${e.message})',
      );
    } catch (e) {
      return AuthResult.failure('Đã xảy ra lỗi: $e');
    }
  }

  /// Đăng xuất: Thu hồi phiên ở Backend và dọn dẹp sạch dữ liệu phiên ở thiết bị
  Future<void> logout() async {
    try {
      if (_client.token != null) {
        await _client.dio.post('/auth/logout');
      }
    } on DioException catch (e) {
      // Cho dù server lỗi hoặc mất mạng, vẫn cho phép đăng xuất sạch ở client
      debugPrint('[AUTH LOGOUT] Backend error: ${e.response?.statusCode} - ${e.message}');
    } catch (e) {
      debugPrint('[AUTH LOGOUT] Unexpected error: $e');
    } finally {
      _client.clearToken();
      _refreshToken = null;
      currentUser = null;
    }
  }
}

