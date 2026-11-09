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
    this.total, {
    this.startTime,
  });
  final DateTime? startTime;
  final String court, player, time, status, total;
}

/// Optional daily operational snapshot; absent until a live Owner feed exists.
class OwnerDaySnapshot {
  const OwnerDaySnapshot({
    required this.totalCourts,
    required this.availableCourts,
    required this.inUseCourts,
    required this.maintenanceCourts,
    required this.bookingCount,
    required this.upcoming,
  });
  final int totalCourts,
      availableCourts,
      inUseCourts,
      maintenanceCourts,
      bookingCount;
  final List<DashboardBooking> upcoming;
}

class DashboardTrendPoint {
  const DashboardTrendPoint({
    required this.period,
    required this.revenue,
    required this.bookingCount,
    required this.bookedHours,
  });
  final String period;
  final num revenue;
  final int bookingCount;
  final num bookedHours;

  factory DashboardTrendPoint.fromJson(Map<String, dynamic> json) {
    return DashboardTrendPoint(
      period: json['period']?.toString() ?? '',
      revenue: (json['revenue'] as num?) ?? 0,
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
      bookedHours: (json['bookedHours'] as num?) ?? 0,
    );
  }
}

class DashboardCourtUtilization {
  const DashboardCourtUtilization({
    required this.courtId,
    required this.courtName,
    required this.facilityId,
    required this.facilityName,
    required this.status,
    required this.bookingCount,
    required this.revenue,
    required this.bookedHours,
    required this.availableHours,
    required this.utilizationRate,
  });
  final int courtId;
  final String courtName;
  final int facilityId;
  final String facilityName;
  final String status;
  final int bookingCount;
  final num revenue;
  final num bookedHours;
  final num availableHours;
  final double? utilizationRate;

  factory DashboardCourtUtilization.fromJson(Map<String, dynamic> json) {
    return DashboardCourtUtilization(
      courtId: (json['courtId'] as num?)?.toInt() ?? 0,
      courtName: json['courtName']?.toString() ?? '',
      facilityId: (json['facilityId'] as num?)?.toInt() ?? 0,
      facilityName: json['facilityName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      bookingCount: (json['bookingCount'] as num?)?.toInt() ?? 0,
      revenue:
          (json['revenue'] as num?) ??
          (json['grossBookedRevenue'] as num?) ??
          0,
      bookedHours:
          (json['bookedHours'] as num?) ?? (json['reservedHours'] as num?) ?? 0,
      availableHours: (json['availableHours'] as num?) ?? 0,
      utilizationRate: (json['utilizationRate'] as num?)?.toDouble(),
    );
  }
}

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.dataStatus,
    required this.grossBookedRevenue,
    required this.collectedRevenue,
    required this.totalBookings,
    required this.confirmedBookings,
    required this.occupancyRatePercent,
    required this.bookedHours,
    required this.availableHours,
    required this.byStatus,
    required this.trendSeries,
    required this.courts,
    this.fromDate,
    this.toDate,
    this.facilityId,
  });

  final String dataStatus;
  final num? grossBookedRevenue;
  final num? collectedRevenue;
  final int? totalBookings;
  final int? confirmedBookings;
  final double? occupancyRatePercent;
  final num? bookedHours;
  final num? availableHours;
  final Map<String, int> byStatus;
  final List<DashboardTrendPoint> trendSeries;
  final List<DashboardCourtUtilization> courts;
  final String? fromDate;
  final String? toDate;
  final int? facilityId;
}

class DashboardDateRange {
  const DashboardDateRange({
    required this.from,
    required this.to,
    required this.startDateIso,
    required this.endDateIso,
    required this.granularity,
  });

  final String from;
  final String to;
  final String startDateIso;
  final String endDateIso;
  final String granularity;

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DashboardDateRange forPeriod(String period, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime.utc(current.year, current.month, current.day);
    late final DateTime start;
    late final String granularity;

    switch (period) {
      case '7 Days':
        start = today.subtract(const Duration(days: 6));
        granularity = 'day';
        break;
      case 'This Month':
        final firstOfMonth = DateTime.utc(today.year, today.month, 1);
        start = today.difference(firstOfMonth).inDays >= 1
            ? firstOfMonth
            : today.subtract(const Duration(days: 29));
        granularity = 'day';
        break;
      case '3 Months':
        start = today.subtract(const Duration(days: 89));
        granularity = 'month';
        break;
      case '6 Months':
        start = today.subtract(const Duration(days: 179));
        granularity = 'month';
        break;
      case 'This Year':
        final firstOfYear = DateTime.utc(today.year, 1, 1);
        start = today.difference(firstOfYear).inDays >= 1
            ? firstOfYear
            : today.subtract(const Duration(days: 364));
        granularity = 'month';
        break;
      default:
        start = today.subtract(const Duration(days: 29));
        granularity = 'day';
    }

    final endExclusive = today.add(const Duration(days: 1));
    return DashboardDateRange(
      from: _ymd(start),
      to: _ymd(today),
      startDateIso: start.toIso8601String(),
      endDateIso: endExclusive.toIso8601String(),
      granularity: granularity,
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.people,
    required this.facilities,
    required this.preview,
    this.analytics,
    this.bookings = const [],
    this.ownerDay,
  });
  final List<DashboardPerson> people;
  final List<DashboardFacility> facilities;
  final bool preview;
  final DashboardAnalytics? analytics;
  final List<DashboardBooking> bookings;
  final OwnerDaySnapshot? ownerDay;

  int get playerCount =>
      preview ? 1284 : people.where((p) => p.role == 'PLAYER').length;
  int get ownerCount =>
      preview ? 42 : people.where((p) => p.role == 'COURT_OWNER').length;
  int get courtCount => preview
      ? 186
      : facilities.isNotEmpty
      ? facilities.fold(0, (a, f) => a + f.courts)
      : (analytics?.courts.length ?? 0);
}

/// Design fixtures are explicit and never substituted for a failed API request.
abstract final class DashboardFixtures {
  static const grossBookedValue = 24850000;
  static const bookingCount = 326;
  static const occupancyPercent = 76.0;
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
  // The approved Owner daily example is a six-court facility. Keep Admin's
  // independent platform fixtures and every live API response unchanged.
  static const ownerData = DashboardData(
    preview: true,
    people: [],
    facilities: [
      DashboardFacility(
        1,
        'Sky Badminton Center',
        6,
        address: 'Da Nang, Vietnam',
        status: 'Active',
      ),
    ],
    bookings: bookings,
    ownerDay: OwnerDaySnapshot(
      totalCourts: 6,
      availableCourts: 4,
      inUseCourts: 1,
      maintenanceCourts: 1,
      bookingCount: 12,
      upcoming: bookings,
    ),
  );
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
    bookings: bookings,
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

  Future<DashboardData> load(
    DashboardRole role, {
    bool preview = false,
    String? period,
    int? facilityId,
    DateTime? now,
    DateTime? bookingDate,
  }) async {
    if (preview) {
      return role == DashboardRole.owner
          ? DashboardFixtures.ownerData
          : DashboardFixtures.data;
    }
    final token = _token();
    final expected = role == DashboardRole.admin ? 'ADMIN' : 'COURT_OWNER';
    if (token == null || _role() != expected) {
      throw const DashboardSessionException();
    }
    final options = Options(extra: {'expectedAuthToken': token});
    final effectivePeriod =
        period ?? (role == DashboardRole.admin ? '6 Months' : '7 Days');
    final dateRange = DashboardDateRange.forPeriod(effectivePeriod, now: now);

    final overviewQuery = <String, dynamic>{
      'startDate': dateRange.startDateIso,
      'endDate': dateRange.endDateIso,
      'facilityId': ?facilityId,
    };
    final revenueQuery = <String, dynamic>{
      'from': dateRange.from,
      'to': dateRange.to,
      'facilityId': ?facilityId,
    };
    final trendQuery = <String, dynamic>{
      'from': dateRange.from,
      'to': dateRange.to,
      'granularity': dateRange.granularity,
      'facilityId': ?facilityId,
    };

    final day = bookingDate ?? now ?? DateTime.now();
    final dayStart = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(const Duration(hours: 7));
    final results = await Future.wait([
      _dio.get(
        role == DashboardRole.admin ? '/facilities' : '/facilities/my',
        options: options,
      ),
      if (role == DashboardRole.admin) _dio.get('/users', options: options),
      _dio.get(
        role == DashboardRole.admin
            ? '/analytics/admin/overview'
            : '/analytics/owner/overview',
        queryParameters: overviewQuery,
        options: options,
      ),
      _dio.get(
        '/analytics/revenue/overview',
        queryParameters: revenueQuery,
        options: options,
      ),
      _dio.get(
        '/analytics/revenue/trend',
        queryParameters: trendQuery,
        options: options,
      ),
      _dio.get(
        '/analytics/revenue/court-utilization',
        queryParameters: revenueQuery,
        options: options,
      ),
      if (role == DashboardRole.owner)
        _dio.get(
          '/bookings/owner',
          queryParameters: {
            'startDate': dayStart.toIso8601String(),
            'endDate': dayStart.add(const Duration(days: 1)).toIso8601String(),
            'facilityId': ?facilityId,
          },
          options: options,
        ),
    ]);
    if (_token() != token || _role() != expected) {
      throw const DashboardSessionException();
    }
    final facilitiesRaw = results[0].data;
    final facilities = facilitiesRaw is List
        ? facilitiesRaw
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
              .toList(growable: false)
        : <DashboardFacility>[];

    var offset = 1;
    final people = role == DashboardRole.admin
        ? ((results[offset++].data as List?) ?? const [])
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

    final scopeOverviewRaw = results[offset++].data;
    final revenueOverviewRaw = results[offset++].data;
    final trendRaw = results[offset++].data;
    final utilizationRaw = results[offset++].data;

    final analytics = _parseAnalytics(
      scopeOverviewRaw: scopeOverviewRaw,
      revenueOverviewRaw: revenueOverviewRaw,
      trendRaw: trendRaw,
      utilizationRaw: utilizationRaw,
      defaultFrom: dateRange.from,
      defaultTo: dateRange.to,
      facilityId: facilityId,
    );

    return DashboardData(
      people: people,
      facilities: facilities,
      preview: false,
      analytics: analytics,
      bookings: role == DashboardRole.owner
          ? (results.last.data as List)
                .map((raw) {
                  final b = Map<String, dynamic>.from(raw as Map);
                  final start = DateTime.parse(b['startTime'] as String)
                      .toUtc()
                      .add(const Duration(hours: 7));
                  final end = DateTime.parse(b['endTime'] as String)
                      .toUtc()
                      .add(const Duration(hours: 7));
                  String time(DateTime d) =>
                      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                  final status = b['status'].toString().toLowerCase();
                  return DashboardBooking(
                    (b['court'] as Map)['name'].toString(),
                    (b['user'] as Map?)?['fullName']?.toString() ?? 'Player',
                    '${time(start)}–${time(end)}',
                    '${status[0].toUpperCase()}${status.substring(1)}',
                    '${b['totalPrice']} VND',
                    startTime: DateTime.parse(b['startTime'] as String),
                  );
                })
                .toList(growable: false)
          : const [],
    );
  }

  DashboardAnalytics? _parseAnalytics({
    required Object? scopeOverviewRaw,
    required Object? revenueOverviewRaw,
    required Object? trendRaw,
    required Object? utilizationRaw,
    required String defaultFrom,
    required String defaultTo,
    required int? facilityId,
  }) {
    if (scopeOverviewRaw is! Map &&
        revenueOverviewRaw is! Map &&
        trendRaw is! Map &&
        utilizationRaw is! Map) {
      return null;
    }

    final scopeMap = scopeOverviewRaw is Map
        ? Map<String, dynamic>.from(scopeOverviewRaw)
        : const <String, dynamic>{};
    final summaryMap = scopeMap['summary'] is Map
        ? Map<String, dynamic>.from(scopeMap['summary'] as Map)
        : const <String, dynamic>{};
    final revMap = revenueOverviewRaw is Map
        ? Map<String, dynamic>.from(revenueOverviewRaw)
        : const <String, dynamic>{};
    final trendMap = trendRaw is Map
        ? Map<String, dynamic>.from(trendRaw)
        : const <String, dynamic>{};
    final utilMap = utilizationRaw is Map
        ? Map<String, dynamic>.from(utilizationRaw)
        : const <String, dynamic>{};

    final dataStatus = scopeMap['dataStatus']?.toString() ?? 'READY';
    final grossBookedRevenue =
        (revMap['grossBookedRevenue'] as num?) ??
        (revMap['revenue'] as num?) ??
        (summaryMap['grossBookedRevenue'] as num?);
    final collectedRevenue = revMap['collectedRevenue'] as num?;
    final totalBookings =
        (revMap['totalBookings'] as num?)?.toInt() ??
        (summaryMap['totalBookings'] as num?)?.toInt();
    final confirmedBookings = (revMap['confirmedBookings'] as num?)?.toInt();

    double? occupancyRatePercent;
    if (summaryMap['reservedOccupancyRatePercent'] is num) {
      occupancyRatePercent = (summaryMap['reservedOccupancyRatePercent'] as num)
          .toDouble();
    } else if (revMap['occupancyRate'] is num) {
      occupancyRatePercent =
          ((revMap['occupancyRate'] as num).toDouble() * 10000).round() / 100;
    }

    final byStatus = <String, int>{
      'PENDING': 0,
      'CONFIRMED': 0,
      'CANCELLED': 0,
      'COMPLETED': 0,
    };
    if (revMap['byStatus'] is Map) {
      final rawStatus = Map<String, dynamic>.from(revMap['byStatus'] as Map);
      for (final entry in rawStatus.entries) {
        if (entry.value is num) {
          byStatus[entry.key.toUpperCase()] = (entry.value as num).toInt();
        }
      }
    } else if (summaryMap['bookingStatusBreakdown'] is Map) {
      final rawStatus = Map<String, dynamic>.from(
        summaryMap['bookingStatusBreakdown'] as Map,
      );
      for (final entry in rawStatus.entries) {
        if (entry.value is num) {
          byStatus[entry.key.toUpperCase()] = (entry.value as num).toInt();
        }
      }
    }

    final trendSeries = (trendMap['series'] is List)
        ? (trendMap['series'] as List)
              .whereType<Map>()
              .map(
                (item) => DashboardTrendPoint.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <DashboardTrendPoint>[];

    final courts = (utilMap['courts'] is List)
        ? (utilMap['courts'] as List)
              .whereType<Map>()
              .map(
                (item) => DashboardCourtUtilization.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <DashboardCourtUtilization>[];

    final rangeMap = revMap['range'] is Map
        ? Map<String, dynamic>.from(revMap['range'] as Map)
        : const <String, dynamic>{};

    return DashboardAnalytics(
      dataStatus: dataStatus,
      grossBookedRevenue: grossBookedRevenue,
      collectedRevenue: collectedRevenue,
      totalBookings: totalBookings,
      confirmedBookings: confirmedBookings,
      occupancyRatePercent: occupancyRatePercent,
      bookedHours: revMap['bookedHours'] as num?,
      availableHours: revMap['availableHours'] as num?,
      byStatus: byStatus,
      trendSeries: trendSeries,
      courts: courts,
      fromDate: rangeMap['from']?.toString() ?? defaultFrom,
      toDate: rangeMap['to']?.toString() ?? defaultTo,
      facilityId: facilityId,
    );
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);
