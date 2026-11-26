import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for the refresh token only. Access tokens stay in memory.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const _key = 'smatch.session.v1';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> save({
    required String refreshToken,
    required Map<String, dynamic> user,
  }) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({'refreshToken': refreshToken, 'user': user}),
      );
    } catch (_) {
      // A storage failure must never block an otherwise valid sign-in.
    }
  }

  Future<({String refreshToken, Map<String, dynamic> user})?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final token = decoded['refreshToken'];
      final user = decoded['user'];
      if (token is! String || token.isEmpty || user is! Map) return null;
      return (refreshToken: token, user: Map<String, dynamic>.from(user));
    } catch (_) {
      return null;
    }
  }

  Future<void> updateRefreshToken(String refreshToken) async {
    final saved = await read();
    if (saved == null) return;
    await save(refreshToken: refreshToken, user: saved.user);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Ignore: the in-memory session is cleared regardless.
    }
  }
}
