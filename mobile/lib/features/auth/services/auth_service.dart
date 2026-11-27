import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';

class AuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final Map<String, dynamic>? user;
  final String? accessToken;
  final bool needsOnboarding;

  AuthResult._({
    required this.isSuccess,
    this.errorMessage,
    this.user,
    this.accessToken,
    this.needsOnboarding = false,
  });

  factory AuthResult.success({
    Map<String, dynamic>? user,
    String? accessToken,
    bool needsOnboarding = false,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      accessToken: accessToken,
      needsOnboarding: needsOnboarding,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult._(isSuccess: false, errorMessage: errorMessage);
  }
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  final _client = ApiClient.instance;

  Map<String, dynamic>? currentUser;
  String? _refreshToken;
  String? get refreshToken => _refreshToken;
  Future<void>? _googleInit;

  // Set only by the debug developer entrypoint. Build defines take precedence.
  String? devGoogleServerClientId;
  String? devGoogleIosClientId;

  Future<String?> _selectGoogleToken() async {
    const configuredServerId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );
    const configuredIosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    final serverId = configuredServerId.isNotEmpty
        ? configuredServerId
        : (kDebugMode ? devGoogleServerClientId ?? '' : '');
    final iosId = configuredIosId.isNotEmpty
        ? configuredIosId
        : (kDebugMode ? devGoogleIosClientId ?? '' : '');
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb ||
        (!ios && defaultTargetPlatform != TargetPlatform.android) ||
        serverId.isEmpty ||
        (ios && iosId.isEmpty)) {
      throw StateError('Google Sign-In is not configured on this device.');
    }
    final google = GoogleSignIn.instance;
    try {
      await (_googleInit ??= google.initialize(
        serverClientId: serverId,
        clientId: ios ? iosId : null,
      ));
      // Always present account selection when linking; the OS handles credentials.
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an identity token.');
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<bool> googleOnboardingPending() async {
    final token = _client.token;
    if (token == null) throw StateError('Please sign in again.');
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/auth/google/onboarding',
      options: Options(extra: {'expectedAuthToken': token}),
    );
    if (_client.token != token || response.data?['needsOnboarding'] is! bool) {
      throw StateError('Could not verify onboarding status.');
    }
    return response.data!['needsOnboarding'] as bool;
  }

  Future<bool> googleLinked() async {
    final token = _client.token;
    if (token == null) throw StateError('Please sign in again.');
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/auth/google/link',
      options: Options(extra: {'expectedAuthToken': token}),
    );
    if (_client.token != token) throw StateError('Your session changed.');
    return response.data?['linked'] == true;
  }

  Future<AuthResult?> linkGoogleAccount() async {
    final token = _client.token;
    if (token == null || currentUser == null) {
      return AuthResult.failure('Please sign in again.');
    }
    try {
      final idToken = await _selectGoogleToken();
      if (idToken == null) return null;
      if (idToken.isEmpty) {
        return AuthResult.failure('Google did not return an identity token.');
      }
      if (_client.token != token) {
        return AuthResult.failure('Your session changed. Please try again.');
      }
      await _client.dio.post(
        '/auth/google/link',
        data: {'idToken': idToken},
        options: Options(extra: {'expectedAuthToken': token}),
      );
      if (_client.token != token) {
        return AuthResult.failure('Your session changed. Please try again.');
      }
      return AuthResult.success();
    } on DioException catch (error) {
      final detail = error.response?.data is Map
          ? error.response?.data['message']
          : null;
      return AuthResult.failure(switch (error.response?.statusCode) {
        401 => 'Your session expired or Google authorization is invalid. Please sign in again.',
        409 when detail == 'Google identity does not match this account' =>
          'The Google email does not match your S-Match account.',
        409 => 'This Google account or S-Match account is already linked.',
        _ => 'Unable to link Google. Check your connection and try again.',
      });
    } on StateError catch (error) {
      return AuthResult.failure(error.message);
    } catch (_) {
      return AuthResult.failure(
        'Google Sign-In could not be completed. Please try again.',
      );
    }
  }

  Future<AuthResult?> loginWithGoogle() async {
    const configuredServerId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );
    const configuredIosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    final serverId = configuredServerId.isNotEmpty
        ? configuredServerId
        : (kDebugMode ? devGoogleServerClientId ?? '' : '');
    final iosId = configuredIosId.isNotEmpty
        ? configuredIosId
        : (kDebugMode ? devGoogleIosClientId ?? '' : '');
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb ||
        (!ios && defaultTargetPlatform != TargetPlatform.android) ||
        serverId.isEmpty ||
        (ios && iosId.isEmpty)) {
      return AuthResult.failure(
        'Google Sign-In is not configured on this device.',
      );
    }
    final google = GoogleSignIn.instance;
    final startingToken = _client.token;
    try {
      await (_googleInit ??= google.initialize(
        serverClientId: serverId,
        clientId: ios ? iosId : null,
      ));
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return AuthResult.failure('Google did not return an identity token.');
      }
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {'idToken': idToken},
      );
      if (startingToken != _client.token) return null;
      final data = response.data;
      final access = data?['accessToken'] as String?;
      final refresh = data?['refreshToken'] as String?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (access == null || refresh == null || user == null) {
        return AuthResult.failure(
          'Google Sign-In did not return a valid session.',
        );
      }
      _client.setToken(access, refreshToken: refresh);
      _refreshToken = refresh;
      currentUser = user;
      _rememberSession(refresh, user);
      return AuthResult.success(
        user: user,
        accessToken: access,
        needsOnboarding: data?['needsOnboarding'] == true,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      return AuthResult.failure('Google Sign-In could not be completed.');
    } on DioException catch (error) {
      return AuthResult.failure(switch (error.response?.statusCode) {
        409 => 'This email already has an account. Sign in with your password.',
        503 => 'Google Sign-In is not configured on the server.',
        _ => 'Google Sign-In could not be completed.',
      });
    } catch (_) {
      return AuthResult.failure('Google Sign-In could not be completed.');
    }
  }

  /// Đăng nhập bằng Email và Password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['accessToken'] as String?;
        final refreshToken = data['refreshToken'] as String?;
        final user = data['user'] as Map<String, dynamic>?;

        if (accessToken != null) {
          _client.setToken(accessToken, refreshToken: refreshToken);
          _refreshToken = refreshToken;
          currentUser = user;
          if (refreshToken != null && user != null) {
            _rememberSession(refreshToken, user);
          }
        }

        return AuthResult.success(user: user, accessToken: accessToken);
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

  void _rememberSession(String refreshToken, Map<String, dynamic> user) {
    unawaited(
      SessionStore.instance.save(refreshToken: refreshToken, user: user),
    );
  }

  /// Restores a persisted session on cold start. Returns true only when the
  /// stored refresh token is still accepted by the backend.
  Future<bool> restoreSession() async {
    final initialVersion = _client.sessionVersion;
    final saved = await SessionStore.instance.read();
    if (_client.sessionVersion != initialVersion || saved == null) return false;
    _client.setToken(null, refreshToken: saved.refreshToken);
    final version = _client.sessionVersion;
    final restored = await _client.tryRefreshSession();
    if (_client.sessionVersion != version) return false;
    final rotated = _client.refreshToken;
    if (!restored || _client.token == null || rotated == null) {
      _client.clearToken();
      _refreshToken = null;
      currentUser = null;
      await SessionStore.instance.clear();
      return false;
    }
    _refreshToken = rotated;
    currentUser = saved.user;
    await SessionStore.instance.save(refreshToken: rotated, user: saved.user);
    return true;
  }

  /// Đăng xuất: Thu hồi phiên ở Backend và dọn dẹp sạch dữ liệu phiên ở thiết bị
  Future<void> logout() async {
    final version = _client.sessionVersion;
    final token = _client.token;
    try {
      if (token != null) {
        await _client.dio.post('/auth/logout', options: Options(extra: {'expectedAuthToken': token}));
      }
    } on DioException catch (e) {
      // Cho dù server lỗi hoặc mất mạng, vẫn cho phép đăng xuất sạch ở client
      debugPrint(
        '[AUTH LOGOUT] Backend error: ${e.response?.statusCode} - ${e.message}',
      );
    } catch (e) {
      debugPrint('[AUTH LOGOUT] Unexpected error: $e');
    } finally {
      if (_client.sessionVersion == version) {
        _client.clearToken();
        _refreshToken = null;
        currentUser = null;
        await SessionStore.instance.clear();
      }
    }
  }
}
