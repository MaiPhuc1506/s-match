import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'auth_service.dart';

/// Fields supported by GET/PATCH /players/profile/me for the Edit Profile form.
/// Location, dominant hand and preferred mode are not part of UpdateProfileDto.
class OwnPlayerProfile {
  const OwnPlayerProfile({required this.fullName, required this.bio});
  final String fullName;
  final String bio;

  factory OwnPlayerProfile.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['playerProfile'];
    if (json['fullName'] is! String || rawProfile is! Map) {
      throw const PlayerProfileException('Máy chủ trả về hồ sơ không hợp lệ.');
    }
    final bio = rawProfile['bio'];
    if (bio != null && bio is! String) {
      throw const PlayerProfileException(
        'Máy chủ trả về tiểu sử không hợp lệ.',
      );
    }
    return OwnPlayerProfile(
      fullName: json['fullName'] as String,
      bio: bio as String? ?? '',
    );
  }
}

class PlayerProfileException implements Exception {
  const PlayerProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlayerProfileService {
  PlayerProfileService._();
  static final instance = PlayerProfileService._();
  final _client = ApiClient.instance;

  Future<OwnPlayerProfile> getMyProfile() => _request();

  Future<OwnPlayerProfile> updateMyProfile({
    required String fullName,
    required String bio,
  }) => _request(fullName: fullName.trim(), bio: bio);

  Future<OwnPlayerProfile> _request({String? fullName, String? bio}) async {
    final token = _client.token;
    if (token == null || token.isEmpty) {
      throw const PlayerProfileException(
        'Vui lòng đăng nhập bằng tài khoản Player để lưu hồ sơ.',
      );
    }
    try {
      final response = fullName == null
          ? await _client.dio.get('/players/profile/me')
          : await _client.dio.patch(
              '/players/profile/me',
              data: {'fullName': fullName, 'bio': bio},
            );
      // Do not apply a response from an account that has since logged out/switched.
      if (_client.token != token) {
        throw const PlayerProfileException(
          'Phiên đăng nhập đã thay đổi. Vui lòng mở lại hồ sơ.',
        );
      }
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const PlayerProfileException(
          'Máy chủ trả về hồ sơ không hợp lệ.',
        );
      }
      final profile = OwnPlayerProfile.fromJson(data);
      final current = AuthService.instance.currentUser;
      if (fullName != null && current != null) {
        final currentProfile = current['playerProfile'];
        AuthService.instance.currentUser = {
          ...current,
          'fullName': profile.fullName,
          'playerProfile': {
            if (currentProfile is Map<String, dynamic>) ...currentProfile,
            'bio': profile.bio,
          },
        };
      }
      return profile;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const PlayerProfileException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
      if (error.response?.statusCode == 403) {
        throw const PlayerProfileException(
          'Tài khoản hiện tại không có quyền cập nhật hồ sơ này.',
        );
      }
      final data = error.response?.data;
      final message = data is Map ? data['message'] : null;
      throw PlayerProfileException(
        message is String
            ? message
            : message is List
            ? message.join(', ')
            : 'Không thể kết nối máy chủ. Vui lòng thử lại.',
      );
    }
  }
}
