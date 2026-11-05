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
    'Live Admin uses existing users/facilities APIs and never invents statuses',
    () async {
      final dio = Dio();
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            paths.add(o.path);
            h.resolve(
              Response(
                requestOptions: o,
                data: o.path == '/users'
                    ? [
                        {
                          'id': 1,
                          'fullName': 'Live Player',
                          'role': {'name': 'PLAYER'},
                        },
                      ]
                    : [
                        {
                          'id': 9,
                          'name': 'Live Facility',
                          'courts': [
                            {'id': 1},
                          ],
                        },
                      ],
              ),
            );
          },
        ),
      );
      final data = await DashboardRepository(
        dio: dio,
        token: () => 'admin-token',
        role: () => 'ADMIN',
      ).load(DashboardRole.admin);
      expect(paths, unorderedEquals(['/users', '/facilities']));
      expect(data.preview, isFalse);
      expect(data.playerCount, 1);
      expect(data.people.single.status, isNull);
      expect(data.facilities.single.status, isNull);
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
            ready.complete(o);
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
