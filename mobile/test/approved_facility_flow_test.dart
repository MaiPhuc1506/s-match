import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:mobile/features/booking/services/live_booking_service.dart';
import 'package:mobile/features/booking/widgets/live_facility_schedule.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/court_map/exploration_data.dart';
import 'package:mobile/features/court_map/facility_images.dart';
import 'package:mobile/features/court_map/screens/court_preview_screen.dart';
import 'package:mobile/features/court_map/widgets/facility_gallery.dart';
import 'package:mobile/features/court_map/widgets/facility_services.dart';

Map<String, dynamic> record(String district, int count, int price) => {
  'id': 9000 + count,
  'name': '$district Badminton',
  'address': '$district, Da Nang, Vietnam',
  'operatingHours': [
    for (var day = 0; day < 7; day++)
      {'dayOfWeek': day, 'openTime': '06:00', 'closeTime': '22:00'},
  ],
  'courts': [
    for (var c = 1; c <= count; c++)
      {
        'id': 100 + c,
        'name': 'Court $c',
        'courtType': 'INDOOR',
        'status': 'ACTIVE',
        'timeSlots': [
          for (var day = 0; day < 7; day++)
            for (var h = 6; h < 22; h++)
              {
                'dayOfWeek': day,
                'startTime': '${h.toString().padLeft(2, '0')}:00',
                'endTime': '${(h + 1).toString().padLeft(2, '0')}:00',
                'price': price + (h >= 17 ? 20000 : 0),
                'isActive': true,
              },
        ],
      },
  ],
};

class ScheduleReadFixture extends LiveBookingService {
  @override
  Future<Map<String, dynamic>> facility(int id) async =>
      record('Hoa Khanh', 6, 80000);
  @override
  Future<List<Map<String, dynamic>>> slots(
    int facilityId,
    int courtId,
    String date,
  ) async => [
    for (var h = 6; h < 22; h++)
      {
        'id': courtId * 100 + h,
        'startTime': '${h.toString().padLeft(2, '0')}:00',
        'endTime': '${(h + 1).toString().padLeft(2, '0')}:00',
        'isActive': true,
        'isBooked': false,
        'price': h >= 17 ? 100000 : 80000,
      },
    {
      'id': null,
      'startTime': '23:00',
      'endTime': '24:00',
      'isActive': false,
      'isBooked': false,
      'status': 'LOCKED',
    },
  ];
}

final captureKey = GlobalKey();
Future<void> capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('UI_SCREENSHOTS');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await cupertino.load();
  });
  test('All ten image mappings survive changed database IDs and use existing files', () {
    final paths = <String>{};
    for (final key in FacilityImages.keys) {
      final words = key
          .split('_')
          .map((s) => '${s[0].toUpperCase()}${s.substring(1)}')
          .join(' ');
      final f = CourtLocation.fromJson(record(words, 4, 80000));
      expect(f.photos, isNotEmpty);
      expect(paths.add(f.photos.first), isTrue);
      for (final path in f.photos) {
        expect(File(path).lengthSync(), greaterThan(1000));
      }
    }
    expect(paths.length, 10);
    final unknown = CourtLocation.fromJson({
      'id': 1,
      'name': 'Sân Cầu Lông Test',
    });
    expect(unknown.photos, isEmpty);
    final uploaded = CourtLocation.fromJson({
      ...record('Hoa Khanh', 6, 80000),
      'photos': ['https://example.test/owner-photo.jpg'],
    });
    expect(uploaded.photos, ['https://example.test/owner-photo.jpg']);
  });

  test('Real hourly tariffs coalesce into two ranges, without invented walk-in data', () {
    final groups = facilityTariffs(
      CourtLocation.fromJson(record('Hoa Khanh', 6, 80000)).courts,
    );
    expect(groups, hasLength(1));
    expect(groups.single.courts, contains('Court 6'));
    expect(groups.single.rows, hasLength(2));
    expect(groups.single.rows.first['startTime'], '06:00');
    expect(groups.single.rows.first['endTime'], '17:00');
    expect(groups.single.rows.last['price'], 100000);
    expect(groups.single.rows.every((r) => r['hourly'] == true), isTrue);
  });

  test('Half-hour tariffs are not merged or represented as hourly prices', () {
    final group = facilityTariffs([
      {
        'name': 'Court 1',
        'timeSlots': [
          {
            'dayOfWeek': 1,
            'startTime': '06:00',
            'endTime': '06:30',
            'price': 45000,
          },
          {
            'dayOfWeek': 1,
            'startTime': '06:30',
            'endTime': '07:00',
            'price': 45000,
          },
        ],
      },
    ]).single;
    expect(group.rows, hasLength(2));
    expect(group.rows.first['hourly'], isFalse);
  });

  for (final value in [
    ('Hai Chau', 4, 80000),
    ('Hoa Cuong', 6, 90000),
    ('Thanh Khe', 4, 70000),
    ('An Khe', 3, 70000),
    ('An Hai', 4, 80000),
    ('Son Tra', 6, 100000),
    ('Ngu Hanh Son', 4, 90000),
    ('Hoa Xuan', 5, 80000),
    ('Cam Le', 4, 70000),
    ('Hoa Khanh', 6, 80000),
  ]) {
    testWidgets(
      '${value.$1}: live detail, actual court count and prices fit 393/320',
      (tester) async {
        final facility = CourtLocation.fromJson(
          record(value.$1, value.$2, value.$3),
        );
        await tester.binding.setSurfaceSize(const Size(393, 852));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              facilityDetailProvider(facility.id)
                  .overrideWith((ref) async => facility),
            ],
            child: MaterialApp(
              theme: SMatchTheme.light,
              builder: (_, child) =>
                  RepaintBoundary(key: captureKey, child: child!),
              home: CourtPreviewScreen(location: facility),
            ),
          ),
        );
        await tester.runAsync(() async {
          for (final photo in facility.photos) {
            await precacheImage(
              AssetImage(photo),
              tester.element(find.byType(CourtPreviewScreen)),
            );
          }
        });
        await tester.pumpAndSettle();
        await capture(tester, '${value.$1.replaceAll(' ', '_')}_detail');
        if (value.$1 == 'Hoa Khanh') {
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('facility-pricing-table'))),
            alignment: .3,
          );
          await tester.pumpAndSettle();
          await capture(tester, 'Hoa_Khanh_pricing');
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const Key('facility-service-list'))),
            alignment: .4,
          );
          await tester.pumpAndSettle();
          await capture(tester, 'Hoa_Khanh_services');
        }
        expect(find.text(facility.name), findsOneWidget);
        expect(
          find.textContaining('${value.$2} indoor courts'),
          findsOneWidget,
        );
        expect(find.text('${facilityPrice(value.$3)} ₫'), findsOneWidget);
        expect(find.text('No services listed yet'), findsOneWidget);
        await tester.tap(find.text('Images'));
        await tester.pumpAndSettle();
        expect(find.byType(FacilityGallery), findsOneWidget);
        await capture(tester, '${value.$1.replaceAll(' ', '_')}_gallery');
        await tester.tap(find.byKey(const Key('gallery-thumbnail-0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('viewer-counter')), findsOneWidget);
        if (facility.photos.length > 1) {
          await tester.drag(
            find.byKey(const Key('facility-image-pages')),
            const Offset(-350, 0),
          );
          await tester.pumpAndSettle();
          expect(find.text('2 / 2'), findsOneWidget);
        }
        await tester.tap(find.byKey(const Key('viewer-close')));
        await tester.pumpAndSettle();
        expect(find.byType(FacilityGallery), findsOneWidget);
        await tester.binding.setSurfaceSize(const Size(320, 640));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Gallery supports a real empty state without unrelated images', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FacilityGallery(
          name: 'Test facility',
          photos: const [],
          onBook: () {},
          onServices: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No images yet'), findsOneWidget);
    expect(find.byKey(const Key('gallery-hero')), findsNothing);
  });
  for (final size in [const Size(393, 852), const Size(360, 640)]) {
    testWidgets(
      'Six-court schedule at $size scrolls horizontally and selects one actual hour',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: SMatchTheme.light,
            builder: (_, child) =>
                RepaintBoundary(key: captureKey, child: child!),
            home: LiveFacilitySchedule(
              facilityId: 9006,
              service: ScheduleReadFixture(),
              now: () => DateTime.utc(2026, 11, 18, 0),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (size.width == 393) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/sprint10/courts/hoa_khanh.png'),
              tester.element(find.byType(LiveFacilitySchedule)),
            ),
          );
          await tester.pumpAndSettle();
          await capture(tester, 'Hoa_Khanh_schedule');
        }
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('booking-continue')))
              .onPressed,
          isNull,
        );
        final horizontal = find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        );
        await tester.drag(horizontal, const Offset(-400, 0));
        await tester.pumpAndSettle();
        final scrollState = tester.state<ScrollableState>(
          find
              .descendant(of: horizontal, matching: find.byType(Scrollable))
              .first,
        );
        expect(scrollState.position.pixels, greaterThan(0));
        final slot = find.byKey(const ValueKey('slot-106-18:00 – 19:00'));
        await tester.ensureVisible(slot);
        await tester.drag(find.byType(ListView), const Offset(0, -220));
        await tester.pumpAndSettle();
        await tester.tap(slot);
        await tester.pumpAndSettle();
        expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
        expect(find.text('100,000 VND'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('booking-continue')))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Vietnam evening positions the grid at the next hour and distinguishes expired slots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: SMatchTheme.light,
          builder: (_, child) =>
              RepaintBoundary(key: captureKey, child: child!),
          home: LiveFacilitySchedule(
            facilityId: 9006,
            service: ScheduleReadFixture(),
            now: () => DateTime.utc(2026, 11, 18, 13, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Past'), findsNothing);
      expect(find.text('Locked'), findsWidgets);
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('slot-101-23:00 – 24:00')),
            )
            .onTap,
        isNull,
      );
      expect(find.text('Today'), findsOneWidget);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(of: horizontal, matching: find.byType(Scrollable))
            .first,
      );
      expect(scroll.position.pixels, greaterThan(500));
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('slot-101-20:00 – 21:00')),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const ValueKey('slot-101-21:00 – 22:00')),
            )
            .onTap,
        isNotNull,
      );
      await capture(tester, 'Vietnam_evening_schedule');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Detail loading and API error expose a working retry', (
    tester,
  ) async {
    final f = CourtLocation.fromJson({'id': 77, 'name': 'Test facility'});
    final pending = Completer<CourtLocation>();
    var attempt = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          facilityDetailProvider(77).overrideWith((ref) {
            attempt++;
            return attempt == 1 ? pending.future : Future.value(f);
          }),
        ],
        child: MaterialApp(
          theme: SMatchTheme.light,
          home: CourtPreviewScreen(location: f),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh facility details.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempt, 2);
    expect(find.text('Could not refresh facility details.'), findsNothing);
  });
}
