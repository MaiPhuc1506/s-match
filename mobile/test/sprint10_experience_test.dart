import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mobile/features/player_experience/data/demo_catalog.dart';
import 'package:mobile/features/player_experience/data/demo_booking_service.dart';
import 'package:mobile/features/player_experience/screens/player_home_screen.dart';
import 'package:mobile/features/player_experience/screens/courts_screens.dart';
import 'package:mobile/features/player_experience/screens/learning_screens.dart';
import 'package:mobile/features/player_experience/screens/shop_screens.dart';
import 'package:mobile/features/player_experience/widgets/smash_scot.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/screens/booking_success_screen.dart';
import 'package:mobile/features/booking/screens/booking_history_screen.dart';
import 'package:mobile/features/booking/screens/booking_detail_screen.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';
import 'package:mobile/features/court_map/widgets/court_maplibre_map.dart';
import 'package:mobile/features/court_map/exploration_data.dart';

import 'support/fake_court_map_platform.dart';

void main() {
  const catalogue = DemoCatalog();
  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(393, 852),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(key: UniqueKey(), home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('10 unique demo facilities, courts and existing local photos', () {
    expect(catalogue.facilities.length, 10);
    expect(catalogue.facilities.map((f) => f.id).toSet().length, 10);
    expect(catalogue.facilities.map((f) => f.image).toSet().length, 10);
    final ids = <int>{};
    for (final f in catalogue.facilities) {
      expect(f.location.hasCoordinates, isTrue);
      expect(f.location.demo, isTrue);
      expect(File(f.image).lengthSync(), greaterThan(0));
      for (final c in f.courts) {
        expect(ids.add(c['id'] as int), isTrue);
      }
    }
    for (final l in [
      ...catalogue.courses,
      ...catalogue.coaches,
      ...catalogue.lessons,
    ]) {
      expect(File(l.image).lengthSync(), greaterThan(0));
    }
  });
  test(
    'sandbox preserves facility, pricing and prevents overlapping slots',
    () async {
      final service = DemoBookingService(
        catalogue,
        now: () => DateTime.utc(2026, 11, 1),
      );
      final f = catalogue.facilities[6];
      final id = f.courtId(0);
      final b = await service.book(
        courtId: id,
        startTime: '2026-11-06T18:00:00+07:00',
        endTime: '2026-11-06T19:00:00+07:00',
      );
      expect(b['totalPrice'], f.hourlyPrice + 20000);
      expect(b['demo'], isTrue);
      expect(service.history.single.facilityName, f.name);
      await expectLater(
        service.book(
          courtId: id,
          startTime: '2026-11-06T23:00:00+07:00',
          endTime: '2026-11-07T00:00:00+07:00',
        ),
        throwsStateError,
      );
      expect(
        (await service.slots(
          f.id,
          id,
          '2026-11-06',
        )).any((s) => s['startTime'] == '18:00'),
        isFalse,
      );
      await expectLater(
        service.book(
          courtId: id,
          startTime: '2026-11-06T18:00:00+07:00',
          endTime: '2026-11-06T19:00:00+07:00',
        ),
        throwsStateError,
      );
      await expectLater(
        service.slots(catalogue.facilities.first.id, id, '2026-11-06'),
        throwsStateError,
      );
    },
  );
  test('live API rejects demo court IDs', () async {
    await expectLater(
      LiveBookingService().book(courtId: -10011, startTime: '', endTime: ''),
      throwsStateError,
    );
  });
  for (final entry in {
    'Courts': ExploreCourtsScreen,
    'Courses': LearningScreen,
    'Tips': LearningScreen,
    'Shop': ShopDirectoryScreen,
  }.entries) {
    testWidgets(
      'Home shortcut ${entry.key} opens destination and Back returns',
      (tester) async {
        await pump(tester, const PlayerHomeScreen());
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
        if (entry.key == 'Tips') {
          expect(
            tester.widget<LearningScreen>(find.byType(LearningScreen)).tips,
            isTrue,
          );
        }
        Navigator.of(tester.element(find.byType(entry.value))).pop();
        await tester.pumpAndSettle();
        expect(find.byType(PlayerHomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Home supports narrow screen and large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.4),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const PlayerHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Scot snaps to an edge after dragging', (tester) async {
    await pump(tester, const PlayerHomeScreen());
    final bubble = find.bySemanticsLabel('Smash Scot demo assistant');
    await tester.drag(bubble, const Offset(-280, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(bubble).dx, lessThan(12));
    expect(tester.takeException(), isNull);
  });
  for (final size in [const Size(393, 852), const Size(360, 640)]) {
    testWidgets('Home sections scroll without overflow at $size', (
      tester,
    ) async {
      await pump(tester, const PlayerHomeScreen(), size: size);
      expect(find.text('Ready to Play?'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.text('Discover badminton shops'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Explore search opens correct facility and reviews empty state', (
    tester,
  ) async {
    await pump(tester, const ExploreCourtsScreen());
    await tester.enterText(find.byType(TextField), 'Son Tra');
    await tester.pumpAndSettle();
    expect(find.text('1 facility'), findsOneWidget);
    await tester.tap(find.text('Son Tra Badminton'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DemoCourtDetailScreen>(find.byType(DemoCourtDetailScreen))
          .facilityId,
      -1006,
    );
    await tester.drag(find.byType(TabBar), const Offset(-220, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Map entry uses the registered facilities provider', (
    tester,
  ) async {
    final original = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = FakeCourtMapPlatform.new;
    addTearDown(() => MapLibrePlatform.createInstance = original);
    const registered = CourtLocation(
      id: 45,
      name: 'Registered Facility',
      latitude: 16.06,
      longitude: 108.21,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyCourtsProvider.overrideWith((ref) async => [registered]),
        ],
        child: const MaterialApp(home: DemoCourtsMapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CourtMapLibreMap>(find.byType(CourtMapLibreMap))
          .courts
          .single
          .id,
      45,
    );
    expect(
      tester
          .widget<CourtMapLibreMap>(find.byType(CourtMapLibreMap))
          .courts
          .any((c) => c.demo),
      false,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Lesson content works with video deferred', (tester) async {
    await pump(
      tester,
      const LearningDetailScreen(itemId: 'smash', kind: 'lesson'),
    );
    expect(
      find.text('Video coming soon\nRead the practice steps below.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Step 1'), 160);
    await tester.tap(find.text('Step 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starting position:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Shop disables unverified call and opens contact info', (
    tester,
  ) async {
    await pump(tester, const ShopDetailScreen(shopId: 'racket'));
    await tester.scrollUntilVisible(find.text('Call'), 200);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Call'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();
    expect(
      find.text('No verified phone number supplied for this demo listing.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Scot opens chat with explicitly labelled demo reply', (
    tester,
  ) async {
    await pump(tester, const PlayerHomeScreen());
    await tester.tap(find.bySemanticsLabel('Smash Scot demo assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Court Information'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10 illustrative facilities'), findsOneWidget);
    expect(find.byType(SmashScotChat), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Existing booking UI completes demo and shows isolated history', (
    tester,
  ) async {
    final service = DemoBookingService(
      catalogue,
      now: () => DateTime.utc(2026, 11, 1),
    );
    await pump(
      tester,
      LiveFacilitySchedule(
        facilityId: -1001,
        service: service,
        demo: true,
        now: () => DateTime.utc(2026, 11, 6, 0),
        onViewBookings: () {},
      ),
    );
    await tester.tap(find.text('08:00 – 09:00'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Demo Booking'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSuccessScreen), findsOneWidget);
    expect(find.text('Demo Booking Confirmed!'), findsOneWidget);
    expect(service.history.single.facilityName, 'Hai Chau Badminton');
    await pump(tester, BookingHistoryScreen(demoBookings: service.history));
    expect(find.text('Demo Bookings'), findsOneWidget);
    await tester.tap(find.text('Hai Chau Badminton'));
    await tester.pumpAndSettle();
    final detail = tester.widget<BookingDetailScreen>(
      find.byType(BookingDetailScreen),
    );
    expect(detail.address, catalogue.facilities.first.address);
    expect(detail.photoAsset, catalogue.facilities.first.image);
    expect(detail.readOnly, isTrue);
    Navigator.of(tester.element(find.byType(BookingDetailScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Demo Bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
