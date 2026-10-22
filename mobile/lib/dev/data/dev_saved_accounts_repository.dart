import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Model biểu diễn một tài khoản test được lưu lại trong Developer Testing Hub.
/// TUYỆT ĐỐI KHÔNG LƯU MẬT KHẨU HOẶC TOKEN NHẠY CẢM Ở ĐÂY.
class DevAccount {
  final String id;
  final String label;
  final String email;
  final String role; // 'PLAYER', 'COURT_OWNER', 'ADMIN'
  final String? note;
  final DateTime? lastUsedAt;

  const DevAccount({
    required this.id,
    required this.label,
    required this.email,
    required this.role,
    this.note,
    this.lastUsedAt,
  });

  DevAccount copyWith({
    String? id,
    String? label,
    String? email,
    String? role,
    String? note,
    DateTime? lastUsedAt,
  }) {
    return DevAccount(
      id: id ?? this.id,
      label: label ?? this.label,
      email: email ?? this.email,
      role: role ?? this.role,
      note: note ?? this.note,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'email': email,
      'role': role,
      'note': note,
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }

  factory DevAccount.fromJson(Map<String, dynamic> json) {
    return DevAccount(
      id: json['id'] as String? ?? 'acc_${DateTime.now().millisecondsSinceEpoch}',
      label: json['label'] as String? ?? 'Unnamed Account',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'PLAYER',
      note: json['note'] as String?,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.tryParse(json['lastUsedAt'] as String)
          : null,
    );
  }
}

/// Repository quản lý danh sách tài khoản test dành riêng cho Developer Mode.
/// Dữ liệu metadata được lưu trữ an toàn (không có password), hỗ trợ fallback bộ nhớ đệm
/// để không bao giờ gây crash app trên mọi môi trường thiết bị / simulator.
class DevSavedAccountsRepository {
  static final DevSavedAccountsRepository instance =
      DevSavedAccountsRepository._internal();

  DevSavedAccountsRepository._internal();

  static const String _fileName = 'smatch_dev_accounts.json';
  List<DevAccount>? _cache;

  /// Danh sách tài khoản seed mặc định chuẩn hệ thống backend S-Match
  static final List<DevAccount> defaultSeedAccounts = [
    const DevAccount(
      id: 'seed_player_01',
      label: 'Player 01 (Demo)',
      email: 'player@smatch.dev',
      role: 'PLAYER',
      note: 'Tài khoản Player chính với hồ sơ & sở thích đã seed',
    ),
    const DevAccount(
      id: 'seed_player_02',
      label: 'Player 02 (Invitee)',
      email: 'player2@smatch.dev',
      role: 'PLAYER',
      note: 'Tài khoản Player phụ dùng để test mời trận / nhận request',
    ),
    const DevAccount(
      id: 'seed_owner_01',
      label: 'Court Owner 01',
      email: 'owner@smatch.dev',
      role: 'COURT_OWNER',
      note: 'Chủ sân Demo - Quản lý cụm sân, lịch hoạt động & slot',
    ),
    const DevAccount(
      id: 'seed_admin_01',
      label: 'System Admin 01',
      email: 'admin@smatch.dev',
      role: 'ADMIN',
      note: 'Quản trị viên hệ thống S-Match toàn quyền',
    ),
  ];

  File? _getStorageFile() {
    try {
      final tempDir = Directory.systemTemp.path;
      return File('$tempDir/$_fileName');
    } catch (e) {
      debugPrint('[DEV REPO] Cannot resolve storage path: $e');
      return null;
    }
  }

  /// Lấy toàn bộ danh sách tài khoản (đọc từ file hoặc trả về cache/defaults)
  Future<List<DevAccount>> getAccounts() async {
    if (_cache != null) {
      return List.unmodifiable(_cache!);
    }

    final file = _getStorageFile();
    if (file != null && file.existsSync()) {
      try {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content) as List<dynamic>;
          _cache = list
              .map((item) => DevAccount.fromJson(item as Map<String, dynamic>))
              .toList();
          return List.unmodifiable(_cache!);
        }
      } catch (e) {
        debugPrint('[DEV REPO] Error reading stored accounts: $e');
      }
    }

    // Nếu chưa có file hoặc lỗi, khởi tạo với danh sách seed mặc định
    _cache = List.from(defaultSeedAccounts);
    await _persist();
    return List.unmodifiable(_cache!);
  }

  /// Lưu hoặc cập nhật một tài khoản
  Future<void> saveAccount(DevAccount account) async {
    final accounts = (await getAccounts()).toList();
    final index = accounts.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.insert(0, account);
    }
    _cache = accounts;
    await _persist();
  }

  /// Đổi tên / sửa nhãn tài khoản
  Future<void> renameAccount(String id, String newLabel) async {
    final accounts = (await getAccounts()).toList();
    final index = accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(label: newLabel);
      _cache = accounts;
      await _persist();
    }
  }

  /// Xóa tài khoản
  Future<void> removeAccount(String id) async {
    final accounts = (await getAccounts()).toList();
    accounts.removeWhere((a) => a.id == id);
    _cache = accounts;
    await _persist();
  }

  /// Đánh dấu tài khoản vừa được đăng nhập
  Future<void> markAccountUsed(String id) async {
    final accounts = (await getAccounts()).toList();
    final index = accounts.indexWhere((a) => a.id == id);
    if (index >= 0) {
      accounts[index] = accounts[index].copyWith(lastUsedAt: DateTime.now());
      _cache = accounts;
      await _persist();
    }
  }

  /// Khôi phục về danh sách tài khoản seed mặc định
  Future<void> resetToDefaults() async {
    _cache = List.from(defaultSeedAccounts);
    await _persist();
  }

  Future<void> _persist() async {
    if (_cache == null) return;
    final file = _getStorageFile();
    if (file == null) return;
    try {
      final jsonStr = jsonEncode(_cache!.map((a) => a.toJson()).toList());
      await file.writeAsString(jsonStr, flush: true);
    } catch (e) {
      debugPrint('[DEV REPO] Error writing dev accounts: $e');
    }
  }
}

