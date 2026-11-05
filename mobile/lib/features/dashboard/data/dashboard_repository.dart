import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/services/auth_service.dart';

enum DashboardRole { owner, admin }

String dashboardRoleName(Object? value) {
  if (value is Map) value = value['name'];
  return value?.toString().toUpperCase() ?? '';
}

class DashboardPerson {
  const DashboardPerson(
    this.id,
    this.name,
    this.role, {
    this.status,
    this.avatar,
  });
  final int id;
  final String name, role;
  final String? status, avatar;
}

class DashboardFacility {
  const DashboardFacility(
    this.id,
    this.name,
    this.courts, {
    this.address = '',
    this.status,
    this.phone,
    this.description,
  });
  final int id, courts;
  final String name, address;
  final String? status, phone, description;
}

class DashboardBooking {
  const DashboardBooking(
    this.court,
    this.player,
    this.time,
    this.status,
    this.total,
  );
  final String court, player, time, status, total;
}

class DashboardData {
  const DashboardData({
    required this.people,
    required this.facilities,
    required this.preview,
  });
  final List<DashboardPerson> people;
  final List<DashboardFacility> facilities;
  final bool preview;

  int get playerCount =>
      preview ? 1284 : people.where((p) => p.role == 'PLAYER').length;
  int get ownerCount =>
      preview ? 42 : people.where((p) => p.role == 'COURT_OWNER').length;
  int get courtCount =>
      preview ? 186 : facilities.fold(0, (a, f) => a + f.courts);
}

/// Design fixtures are explicit and never substituted for a failed API request.
abstract final class DashboardFixtures {
  static const bookings = [
    DashboardBooking(
      'Court 01',
      'Nguyen Van A',
      '18:00–19:00',
      'Confirmed',
      '120,000đ',
    ),
    DashboardBooking(
      'Court 02',
      'Tran Thi B',
      '19:00–20:00',
      'Pending',
      '120,000đ',
    ),
    DashboardBooking(
      'Court 03',
      'Le Minh C',
      '20:00–21:00',
      'Confirmed',
      '120,000đ',
    ),
  ];
  static const data = DashboardData(
    preview: true,
    people: [
      DashboardPerson(
        1,
        'Nguyen Van A',
        'PLAYER',
        status: 'Active',
        avatar: 'users.imgAvatarReusedPortrait',
      ),
      DashboardPerson(
        2,
        'Tran Thi B',
        'PLAYER',
        status: 'Active',
        avatar: 'users.imgAvatarReusedPortrait1',
      ),
      DashboardPerson(
        3,
        'Le Minh C',
        'PLAYER',
        status: 'Suspended',
        avatar: 'users.imgAvatarReusedPortrait2',
      ),
      DashboardPerson(
        4,
        'Pham Gia H',
        'PLAYER',
        status: 'Active',
        avatar: 'users.imgAvatarReusedPortrait3',
      ),
      DashboardPerson(5, 'Sky Court Owner', 'COURT_OWNER', status: 'Active'),
      DashboardPerson(6, 'Star Court Owner', 'COURT_OWNER', status: 'Active'),
    ],
    facilities: [
      DashboardFacility(
        1,
        'Sky Badminton Center',
        12,
        address: 'Da Nang, Vietnam',
        status: 'Active',
      ),
      DashboardFacility(
        2,
        'Star Badminton Club',
        8,
        address: 'Da Nang, Vietnam',
        status: 'Pending',
      ),
      DashboardFacility(
        3,
        'Viet Sport Arena',
        10,
        address: 'Da Nang, Vietnam',
        status: 'Active',
      ),
    ],
  );
}

class DashboardSessionException implements Exception {
  const DashboardSessionException();
  @override
  String toString() => 'Please log in with the correct Owner or Admin account.';
}

class DashboardRepository {
  DashboardRepository({
    Dio? dio,
    String? Function()? token,
    String Function()? role,
  }) : _dio = dio ?? ApiClient.instance.dio,
       _token = token ?? (() => ApiClient.instance.token),
       _role =
           role ??
           (() => dashboardRoleName(AuthService.instance.currentUser?['role']));
  final Dio _dio;
  final String? Function() _token;
  final String Function() _role;

  Future<DashboardData> load(DashboardRole role, {bool preview = false}) async {
    if (preview) return DashboardFixtures.data;
    final token = _token();
    final expected = role == DashboardRole.admin ? 'ADMIN' : 'COURT_OWNER';
    if (token == null || _role() != expected) {
      throw const DashboardSessionException();
    }
    final options = Options(extra: {'expectedAuthToken': token});
    // /bookings/my is the player's own purchases, NOT an Owner booking feed.
    // No Owner booking/analytics endpoint exists in the current backend.
    final results = await Future.wait([
      _dio.get(
        role == DashboardRole.admin ? '/facilities' : '/facilities/my',
        options: options,
      ),
      if (role == DashboardRole.admin) _dio.get('/users', options: options),
    ]);
    if (_token() != token || _role() != expected) {
      throw const DashboardSessionException();
    }
    final facilities = (results.first.data as List)
        .map((raw) {
          final f = Map<String, dynamic>.from(raw as Map);
          return DashboardFacility(
            f['id'] as int,
            f['name'] as String? ?? '',
            (f['courts'] as List?)?.length ?? 0,
            address: f['address'] as String? ?? '',
            phone: f['contactPhone'] as String?,
            description: f['description'] as String?,
          );
        })
        .toList(growable: false);
    final people = role == DashboardRole.admin
        ? (results[1].data as List)
              .map((raw) {
                final p = Map<String, dynamic>.from(raw as Map);
                return DashboardPerson(
                  p['id'] as int,
                  p['fullName'] as String? ?? '',
                  dashboardRoleName(p['role']),
                );
              })
              .toList(growable: false)
        : <DashboardPerson>[];
    return DashboardData(
      people: people,
      facilities: facilities,
      preview: false,
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);
