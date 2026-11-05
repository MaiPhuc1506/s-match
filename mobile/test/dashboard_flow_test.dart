import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/services/auth_service.dart';
import 'package:mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:mobile/features/dashboard/screens/dashboard_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('An unauthenticated dashboard cannot enter facility management', (
    tester,
  ) async {
    ApiClient.instance.clearToken();
    AuthService.instance.currentUser = null;
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardScreen(role: DashboardRole.owner)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-tab-4')));
    await tester.pumpAndSettle();
    expect(find.text('Sign In Required'), findsOneWidget);
    expect(find.text('Manage Facilities'), findsNothing);
    expect(ApiClient.instance.token, isNull);
    expect(tester.takeException(), isNull);
  });

  Future<void> pump(
    WidgetTester tester, {
    DashboardRole role = DashboardRole.owner,
    int tab = 0,
    Size size = const Size(393, 852),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              padding: const EdgeInsets.only(top: 59, bottom: 34),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: DashboardScreen(
            key: UniqueKey(),
            role: role,
            initialTab: tab,
            preview: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Owner tabs preserve bottom navigation position and booking filters work',
    (tester) async {
      await pump(tester);
      final position = tester.getTopLeft(
        find.byKey(const ValueKey('dashboard-tab-0')),
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-tab-2')));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('dashboard-tab-0'))),
        position,
      );
      expect(find.text('Court 01'), findsOneWidget);
      await tester.tap(find.text('Pending').first);
      await tester.pumpAndSettle();
      expect(find.text('Court 01'), findsNothing);
      expect(find.text('Court 02'), findsOneWidget);
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();
      expect(find.text('No bookings'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tran Thi B');
      await tester.pumpAndSettle();
      expect(find.text('Court 01'), findsNothing);
      await tester.tap(find.text('Court 02'));
      await tester.pumpAndSettle();
      expect(find.text('Booking Details'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Court 02'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Admin role tabs search, filter, and chart period sheet', (
    tester,
  ) async {
    await pump(tester, role: DashboardRole.admin, tab: 1);
    await tester.enterText(find.byType(TextField), 'Tran');
    await tester.pumpAndSettle();
    expect(find.text('Tran Thi B'), findsOneWidget);
    expect(find.text('Nguyen Van A'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Owners (42)'));
    await tester.pumpAndSettle();
    expect(find.text('Sky Court Owner'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-tab-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending (28)'));
    await tester.pumpAndSettle();
    expect(find.text('Star Badminton Club'), findsOneWidget);
    expect(find.text('Sky Badminton Center'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-tab-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 Months').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('This Year'));
    await tester.pumpAndSettle();
    expect(find.text('This Year'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(393, 852),
    const Size(320, 568),
    const Size(430, 932),
  ]) {
    testWidgets('All nine dashboard screens fit $size', (tester) async {
      for (final role in DashboardRole.values) {
        for (var tab = 0; tab < 4; tab++) {
          await pump(tester, role: role, tab: tab, size: size);
          expect(tester.takeException(), isNull, reason: '$role tab $tab');
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -400),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$role tab $tab scrolled',
          );
        }
      }
      await tester.pumpWidget(
        const MaterialApp(
          home: OwnerBookingDetailScreen(
            booking: DashboardBooking(
              'Court 01',
              'Nguyen Van A',
              '18:00–19:00',
              'Confirmed',
              '120,000đ',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Larger text remains scrollable with reduced motion', (
    tester,
  ) async {
    for (final role in DashboardRole.values) {
      for (var tab = 0; tab < 4; tab++) {
        await pump(
          tester,
          role: role,
          tab: tab,
          size: const Size(393, 852),
          scale: 1.3,
        );
        expect(tester.takeException(), isNull, reason: '$role tab $tab');
      }
    }
  });

  test('Role guard rejects Player before sending a request', () async {
    final dio = Dio();
    var calls = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          calls++;
          h.resolve(Response(requestOptions: o, data: []));
        },
      ),
    );
    final repository = DashboardRepository(
      dio: dio,
      token: () => 'player-token',
      role: () => 'PLAYER',
    );
    await expectLater(
      repository.load(DashboardRole.admin),
      throwsA(isA<DashboardSessionException>()),
    );
    expect(calls, 0);
  });
  test(
    'Live Admin uses existing users/facilities and analytics APIs and never invents statuses',
    () async {
      final dio = Dio();
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            paths.add(o.path);
            final Object data = switch (o.path) {
              '/users' => [
                {
                  'id': 1,
                  'fullName': 'Live Player',
                  'role': {'name': 'PLAYER'},
                },
              ],
              '/facilities' => [
                {
                  'id': 9,
                  'name': 'Live Facility',
                  'courts': [
                    {'id': 1},
                  ],
                },
              ],
              '/analytics/admin/overview' => {
                'scope': 'ADMIN',
                'dataStatus': 'READY',
                'summary': {
                  'totalActiveUsers': null,
                  'totalFacilities': 1,
                  'totalBookings': 4,
                  'bookingStatusBreakdown': {
                    'pending': 1,
                    'confirmed': 2,
                    'cancelled': 0,
                    'completed': 1,
                  },
                  'reservedOccupancyRatePercent': 18.5,
                  'grossBookedRevenue': 480000,
                },
              },
              '/analytics/revenue/overview' => {
                'range': {'from': '2026-10-01', 'to': '2026-11-01', 'days': 32},
                'revenue': 480000,
                'grossBookedRevenue': 480000,
                'collectedRevenue': null,
                'totalBookings': 4,
                'confirmedBookings': 3,
                'byStatus': {
                  'PENDING': 1,
                  'CONFIRMED': 2,
                  'CANCELLED': 0,
                  'COMPLETED': 1,
                },
                'occupancyRate': 0.185,
              },
              '/analytics/revenue/trend' => {
                'granularity': 'month',
                'totalRevenue': 480000,
                'totalBookings': 4,
                'series': [
                  {
                    'period': '2026-10',
                    'revenue': 300000,
                    'bookingCount': 2,
                    'bookedHours': 4,
                  },
                  {
                    'period': '2026-11',
                    'revenue': 180000,
                    'bookingCount': 2,
                    'bookedHours': 3,
                  },
                ],
              },
              '/analytics/revenue/court-utilization' => {
                'courts': [
                  {
                    'courtId': 1,
                    'courtName': 'Court 1',
                    'facilityId': 9,
                    'facilityName': 'Live Facility',
                    'status': 'ACTIVE',
                    'bookingCount': 3,
                    'revenue': 480000,
                    'bookedHours': 7,
                    'availableHours': 84,
                    'utilizationRate': 0.0833,
                  },
                ],
              },
              _ => const <Object>[],
            };
            h.resolve(Response(requestOptions: o, data: data));
          },
        ),
      );
      final data = await DashboardRepository(
        dio: dio,
        token: () => 'admin-token',
        role: () => 'ADMIN',
      ).load(DashboardRole.admin, period: '6 Months', facilityId: 9);
      expect(
        paths,
        unorderedEquals([
          '/users',
          '/facilities',
          '/analytics/admin/overview',
          '/analytics/revenue/overview',
          '/analytics/revenue/trend',
          '/analytics/revenue/court-utilization',
        ]),
      );
      expect(data.preview, isFalse);
      expect(data.playerCount, 1);
      expect(data.people.single.status, isNull);
      expect(data.facilities.single.status, isNull);
      expect(data.analytics, isNotNull);
      expect(data.analytics!.grossBookedRevenue, 480000);
      expect(data.analytics!.collectedRevenue, isNull);
      expect(data.analytics!.totalBookings, 4);
      expect(data.analytics!.occupancyRatePercent, 18.5);
      expect(data.analytics!.trendSeries, hasLength(2));
      expect(data.analytics!.courts.single.courtName, 'Court 1');
    },
  );
  testWidgets(
    'Live Owner dashboard renders real analytics metrics and updates facility/period filters without fixtures',
    (tester) async {
      final requestedFacilities = <Object?>[];
      final requestedPeriods = <String?>[];
      final repo = _FakeLiveDashboardRepository(
        onLoad: (role, period, facilityId) {
          requestedPeriods.add(period);
          requestedFacilities.add(facilityId);
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dashboardRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: DashboardScreen(role: DashboardRole.owner, preview: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gross Booked Value'), findsOneWidget);
      expect(find.text('640,000đ'), findsOneWidget);
      expect(find.text('14.2%'), findsOneWidget);
      expect(find.text('24,850,000đ'), findsNothing);

      await tester.tap(find.text('Sky Badminton Center'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Star Badminton Club'));
      await tester.pumpAndSettle();
      expect(requestedFacilities.last, 2);
    },
  );
  test(
    'API failure is propagated instead of replaced with design fixtures',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.reject(
            DioException(
              requestOptions: o,
              response: Response(requestOptions: o, statusCode: 403),
            ),
          ),
        ),
      );
      await expectLater(
        DashboardRepository(
          dio: dio,
          token: () => 'owner-token',
          role: () => 'COURT_OWNER',
        ).load(DashboardRole.owner),
        throwsA(isA<DioException>()),
      );
    },
  );
  test(
    'In-flight response cannot be applied after an account switch',
    () async {
      final dio = Dio();
      final ready = Completer<RequestOptions>();
      final reply = Completer<void>();
      var token = 'first';
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) async {
            if (!ready.isCompleted) ready.complete(o);
            await reply.future;
            h.resolve(Response(requestOptions: o, data: []));
          },
        ),
      );
      final pending = DashboardRepository(
        dio: dio,
        token: () => token,
        role: () => 'COURT_OWNER',
      ).load(DashboardRole.owner);
      await ready.future;
      token = 'second';
      final check = expectLater(
        pending,
        throwsA(isA<DashboardSessionException>()),
      );
      reply.complete();
      await check;
    },
  );
}

class _FakeLiveDashboardRepository extends DashboardRepository {
  _FakeLiveDashboardRepository({required this.onLoad})
    : super(token: () => 'owner-token', role: () => 'COURT_OWNER');

  final void Function(DashboardRole role, String? period, int? facilityId)
  onLoad;

  @override
  Future<DashboardData> load(
    DashboardRole role, {
    bool preview = false,
    String? period,
    int? facilityId,
    DateTime? now,
  }) async {
    onLoad(role, period, facilityId);
    return const DashboardData(
      preview: false,
      people: [],
      facilities: [
        DashboardFacility(1, 'Sky Badminton Center', 4),
        DashboardFacility(2, 'Star Badminton Club', 3),
      ],
      analytics: DashboardAnalytics(
        dataStatus: 'READY',
        grossBookedRevenue: 640000,
        collectedRevenue: null,
        totalBookings: 8,
        confirmedBookings: 6,
        occupancyRatePercent: 14.2,
        bookedHours: 12,
        availableHours: 84,
        byStatus: {
          'PENDING': 1,
          'CONFIRMED': 5,
          'CANCELLED': 1,
          'COMPLETED': 1,
        },
        trendSeries: [
          DashboardTrendPoint(
            period: '2026-10-28',
            revenue: 320000,
            bookingCount: 4,
            bookedHours: 6,
          ),
          DashboardTrendPoint(
            period: '2026-10-29',
            revenue: 320000,
            bookingCount: 4,
            bookedHours: 6,
          ),
        ],
        courts: [
          DashboardCourtUtilization(
            courtId: 1,
            courtName: 'Court 1',
            facilityId: 1,
            facilityName: 'Sky Badminton Center',
            status: 'ACTIVE',
            bookingCount: 6,
            revenue: 640000,
            bookedHours: 12,
            availableHours: 84,
            utilizationRate: 0.142,
          ),
        ],
      ),
    );
  }
}
